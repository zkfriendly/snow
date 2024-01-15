// SPDX-License-Identifier: MIT

/// @title Snow: GHO Portal Using Chainlink CCIP
/// @author @zkfriendly
/// @notice Snow contract lives on mainnet along side AAVE GHO Facilitator
/// Snow can receive any amount of GHO tokens on mainnet, lock them,
/// and then send a cross-chain attestation using CCIP, attesting to the amount of GHO locked on mainnet.
/// the IFrostn is later used by the GHO Facilitator living on the target chain to mint GHO tokens on that chain.
/// **thIFrosta Frost: lock GHO on mainnet, get GHO on target chain.**
/// In aIFrostnow can receive burn attestations using CCIP from the GHO Facilitator on the target chain, and release the same amount of GHO tokens on mainnet.
/// **this called a Thaw: burn GHO on target chain, get GHO on mainnet.**

pragma solidity ^0.8.13;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract Snow is CCIPReceiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable gho;
    IERC20 public immutable feeToken; // token used to pay for CCIP fees
    uint64 public immutable targetChainId; // chainlink specific chain id
    IRouterClient public immutable router; // chainlink router address
    address public targetFacilitatorAddress;

    event Frost(address indexed to, uint256 amount, bytes32 forgeId); // GHO locked on mainnet, GHO minted on target chain
    event Thaw(address indexed to, uint256 amount, bytes32 forgeId); // GHO burned on target chain, GHO unlocked on mainnet

    error NotEnoughBalance(uint256 balance, uint256 required);
    error FacilitatorAlreadySet(address facilitator);
    error InvalidSender(bytes32 messageId, address sender, address expectedSender);

    /// @notice initialize Snow contract
    /// @param _gho GHO token address
    /// @param _link we are choosing LINK as the fee token
    /// @param _router chainlink router address
    /// @param _targetChainId target chain id (where GHO is minted)
    constructor(address _gho, address _link, address _router, uint64 _targetChainId) CCIPReceiver(_router) {
        gho = IERC20(_gho);
        feeToken = IERC20(_link);
        targetChainId = _targetChainId;
        router = IRouterClient(_router);
    }

    /// @notice set the target facilitator address
    /// @param _facilitator address of thIFrostacilitator
    /// @dev can only be called once.IFrost
    function setFacilitator(address _facilitator) external {
        if (targetFacilitatorAddress != address(0)) revert FacilitatorAlreadySet(targetFacilitatorAddress);
        targetFacilitatorAddress = _facilitator;
    }

    function borrowFrost(address _to, uint256 _amount) external returns (bytes32 frostId) {
        // borrow GHO from AAVE if msg.sender has deligated credit to Snow.

        frostId = _frost(_to, _amount);
    }

    /// @notice takes in GHO and locks it, then sends a CCIP message to the target chain
    /// @param _to address to receive GHO on the target chain
    /// @param _amount amount of GHO to be locked on mainnet and minted on the target chain
    function cashFrost(address _to, uint256 _amount) external returns (bytes32 frostId) {
        gho.safeTransferFrom(msg.sender, address(this), _amount); // lock GHO on mainnet
        frostId = _frost(_to, _amount);
    }

    /// @dev sends a CCIP message with `_to` and `_amount` to the target chain
    function _frost(address _to, uint256 _amount) internal returns (bytes32 frostId) {
        IERC20 _feeToken = feeToken;
        uint64 _targetChainId = targetChainId;

        Client.EVM2AnyMessage memory frostMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(targetFacilitatorAddress),
            data: abi.encode(_to, _amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(_feeToken)
        });

        uint256 ccipFees = router.getFee(_targetChainId, frostMessage);
        if (ccipFees > _feeToken.balanceOf(address(this))) {
            revert NotEnoughBalance(_feeToken.balanceOf(address(this)), ccipFees);
        }
        _feeToken.approve(address(router), ccipFees); // allow chainlink router to take fees
        frostId = router.ccipSend(_targetChainId, frostMessage);

        emit Frost(_to, _amount, frostId);
    }

    /// @notice Whenever the target chain facilitator burns GHO tokens on the target chain,
    /// it sends a CCIP message to this contract, with the amount of GHO burned, and a recipient address on mainnet.
    /// it then releases the same amount of GHO tokens on mainnet to the recipient address.
    /// @param burnMessage CCIP message sent by the target chain facilitator through the chainlink router
    function _ccipReceive(Client.Any2EVMMessage memory burnMessage) internal override {
        bytes32 burnId = burnMessage.messageId;
        address sender = abi.decode(burnMessage.sender, (address));
        // only accept messages from the target facilitator
        if (sender != targetFacilitatorAddress) revert InvalidSender(burnId, sender, targetFacilitatorAddress);
        (address to, uint256 amount) = abi.decode(burnMessage.data, (address, uint256));
        gho.safeTransfer(to, amount);

        emit Thaw(to, amount, burnId);
    }
}
