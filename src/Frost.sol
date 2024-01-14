// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IGhoToken} from "./interfaces/IGhoToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";

contract Frost is CCIPReceiver {
    using SafeERC20 for IERC20;

    IGhoToken public immutable GHO; // GHO token address
    IRouterClient public immutable ROUTER; // chainlink router address
    uint64 public immutable SOURCE_CHAIN_ID; // source chain id (where collateral is locked)
    address public immutable SNOW; // snow address on the source chain
    IERC20 public immutable FEE_TOKEN; // (LINK, WETH) token address

    event Thaw(address indexed to, uint256 amount, bytes32 thawId);

    error InvalidSender(bytes32 messageId, address sender, address expectedSender);
    error NotEnoughBalance(uint256 balance, uint256 required);

    constructor(address _gho, address _router, address _snow, address _feeToken, uint64 _sourceChainId)
        CCIPReceiver(_router)
    {
        GHO = IGhoToken(_gho);
        ROUTER = IRouterClient(_router);
        SOURCE_CHAIN_ID = _sourceChainId;
        SNOW = _snow;
        FEE_TOKEN = IERC20(_feeToken);
    }

    function thaw(address _to, uint256 _amount) external returns (bytes32 thawId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory thawSignal = Client.EVM2AnyMessage({
            receiver: abi.encode(SNOW), // ABI-encoded receiver address
            data: abi.encode(_to, _amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(FEE_TOKEN)
        });

        // calculate and approve cross-chain transaction fee
        uint256 fee = ROUTER.getFee(SOURCE_CHAIN_ID, thawSignal);
        if (FEE_TOKEN.balanceOf(address(this)) < fee) revert NotEnoughBalance(FEE_TOKEN.balanceOf(address(this)), fee);
        IERC20(FEE_TOKEN).approve(address(ROUTER), fee);

        // send cross-chain message
        thawId = ROUTER.ccipSend(SOURCE_CHAIN_ID, thawSignal);

        // transfer GHO to this contract and burn it
        IERC20(GHO).safeTransferFrom(msg.sender, address(this), _amount);
        GHO.burn(_amount);

        emit Thaw(_to, _amount, thawId);
    }

    /// @notice mint GHO upon receiving a cross-chain message
    /// @param _frostSignal cross-chain message
    function _ccipReceive(Client.Any2EVMMessage memory _frostSignal) internal override {
        address sender = abi.decode(_frostSignal.sender, (address));

        if (sender != SNOW) revert InvalidSender(_frostSignal.messageId, sender, SNOW);

        (address to, uint256 amount) = abi.decode(_frostSignal.data, (address, uint256));
        GHO.mint(to, amount);
    }
}
