// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILinkFrost} from "./interfaces/ILinkFrost.sol";

import {console2} from "forge-std/Test.sol";

contract Snow {
    using SafeERC20 for IERC20;

    IERC20 public immutable GHO; // GHO token address
    LinkTokenInterface public immutable LINK; // LINK token address

    address public immutable TARGET_FACILITATOR_ADDRESS; // GHO facilitator address on the target chain
    uint64 public immutable TARGET_CHAIN_ID; // target chain id

    IRouterClient public immutable ROUTER; // chainlink router address

    event Frost(address indexed to, uint256 amount, bytes32 forgeId);

    error NotEnoughBalance(uint256 balance, uint256 required);

    constructor(
        address _gho,
        address _link,
        address _targetFacilitatorAddress,
        address _router,
        uint64 _targetChainId
    ) {
        GHO = IERC20(_gho);
        LINK = LinkTokenInterface(_link);

        TARGET_FACILITATOR_ADDRESS = _targetFacilitatorAddress;
        TARGET_CHAIN_ID = _targetChainId;

        ROUTER = IRouterClient(_router);
    }

    /// @notice mint GHO on the target chain
    /// @param _to recipient address on the target chain
    /// @param _amount amount of GHO to be minted on the target chain
    function frost(address _to, uint256 _amount) external returns (bytes32 frostId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory frostSignal = Client.EVM2AnyMessage({
            receiver: abi.encode(TARGET_FACILITATOR_ADDRESS), // ABI-encoded receiver address
            data: abi.encodeWithSelector(ILinkFrost.frost.selector, _to, _amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(LINK)
        });

        uint256 fees = ROUTER.getFee(TARGET_CHAIN_ID, frostSignal);

        if (fees > LINK.balanceOf(address(this))) {
            revert NotEnoughBalance(LINK.balanceOf(address(this)), fees);
        }

        LINK.approve(address(ROUTER), fees);
        frostId = ROUTER.ccipSend(TARGET_CHAIN_ID, frostSignal);

        GHO.safeTransferFrom(msg.sender, address(this), _amount);

        emit Frost(_to, _amount, frostId);
    }
}
