// SPDX-License-Identifier: MIT

/// @title Frost: GHO Portal Facilitator using Chainlink CCIP
/// @author @zkfriendly
/// @notice Frost contract is a GHO Facilitator that lives on the target chain
/// Frost receives CCIP messages from the source chain, and mints GHO tokens on the target chain accordingly.
/// Frost can also burn GHO tokens on the target chain, and send a CCIP message to the source chain
/// to unlock the same amount of GHO tokens.

pragma solidity ^0.8.13;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IGhoToken} from "./interfaces/IGhoToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Frost is CCIPReceiver {
    using SafeERC20 for IERC20;

    IGhoToken public immutable gho;
    IRouterClient public immutable router; // chainlink router address
    uint64 public immutable sourceChainId; // chainlink specific chain id
    address public immutable snow; // receives CCIP messages fromt this contract on the source chain
    IERC20 public immutable feeToken; // token used to pay for CCIP fees

    event Mint(address indexed to, uint256 amount, bytes32 frostId); // GHO locked on mainnet, GHO minted on target chain
    event Burn(address indexed to, uint256 amount, bytes32 thawId); // GHO burned on target chain, GHO unlocked on mainnet

    error InvalidSender(bytes32 messageId, address sender, address expectedSender);
    error NotEnoughBalance(uint256 balance, uint256 required);

    /// @notice initialize Frost contract
    /// @param _gho GHO token address
    /// @param _router chainlink router address
    /// @param _snow snow address on the source chain
    /// @param _feeToken (LINK, WETH) token address
    /// @param _sourceChainId source chain id (where collateral is locked)
    constructor(address _gho, address _router, address _snow, address _feeToken, uint64 _sourceChainId)
        CCIPReceiver(_router)
    {
        gho = IGhoToken(_gho);
        router = IRouterClient(_router);
        snow = _snow;
        feeToken = IERC20(_feeToken);
        sourceChainId = _sourceChainId;
    }

    /// @notice takes in GHO and burns it, then sends a CCIP message to the source chain
    /// @param _to address to receive GHO on the source chain
    /// @param _amount amount of GHO to be burned on the target chain and released on the source chain
    function burn(address _to, uint256 _amount) external returns (bytes32 burnId) {
        IERC20 _feeToken = feeToken;
        uint64 _sourceChainId = sourceChainId;
        IGhoToken _gho = gho;
        IRouterClient _router = router;

        Client.EVM2AnyMessage memory burnMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(snow),
            data: abi.encode(_to, _amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
            feeToken: address(_feeToken)
        });

        uint256 ccipFees = _router.getFee(_sourceChainId, burnMessage);
        if (ccipFees > _feeToken.balanceOf(address(this))) {
            revert NotEnoughBalance(_feeToken.balanceOf(address(this)), ccipFees);
        }
        _feeToken.approve(address(_router), ccipFees);
        burnId = _router.ccipSend(_sourceChainId, burnMessage);
        // transfer GHO to this contract and burn it
        IERC20(_gho).safeTransferFrom(msg.sender, address(this), _amount);
        _gho.burn(_amount);

        emit Burn(_to, _amount, burnId);
    }

    /// @notice Whenever the source chain facilitator locks GHO tokens on the source chain,
    /// Frost receives a CCIP message, and mints GHO tokens here (target chain).
    /// @param _mintMessage cross-chain message
    function _ccipReceive(Client.Any2EVMMessage memory _mintMessage) internal override {
        _handleMintMessage(_mintMessage);
    }

    function _handleMintMessage(Client.Any2EVMMessage memory _mintMessage) internal {
        address sender = abi.decode(_mintMessage.sender, (address));
        // only accept messages from the snow contract
        if (sender != snow) revert InvalidSender(_mintMessage.messageId, sender, snow);
        (address to, uint256 amount) = abi.decode(_mintMessage.data, (address, uint256));
        gho.mint(to, amount);
        emit Mint(to, amount, _mintMessage.messageId);
    }
}
