// SPDX-License-Identifier: MIT

/// @title GhoBox: Aave V3 GHO Box
/// @author @zkfriendly

pragma solidity ^0.8.13;

import {IRouterClient} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IGhoBox} from "./interfaces/IGhoBox.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";

contract GhoBox is IGhoBox, CCIPReceiver {
    using SafeERC20 for IERC20;

    address public immutable gho;
    address public immutable pool; // aave v3 pool address
    address public immutable feeToken; // token used to pay for CCIP fees
    uint64 public immutable targetChainId; // chainlink specific chain id
    address public immutable router; // chainlink router address
    address public targetGhoBox;

    // only for mocking and demo purposes
    address public mockGhoToken;

    address internal _admin; // for debug and demo purposes

    BorrowRequest[] public borrowRequests;

    /// @notice construct contract
    /// @param _gho GHO token address
    /// @param _pool aave v3 pool address
    /// @param _link we are choosing LINK as the fee token
    /// @param _router chainlink router address
    /// @param _targetChainId target chain id (where GHO is minted)
    /// @param _mockGhoToken address of the mock GHO token
    constructor(
        address _gho,
        address _pool,
        address _link,
        address _router,
        uint64 _targetChainId,
        address _mockGhoToken // mint and burn are applied to this only for demo purposes
    ) CCIPReceiver(_router) {
        gho = _gho;
        pool = _pool;
        feeToken = _link;
        targetChainId = _targetChainId;
        router = _router;

        mockGhoToken = _mockGhoToken;

        _admin = msg.sender;
    }

    /// @notice set the target gho box address
    /// @param _ghoBox address of the target facilitator
    /// @dev can only be called once.
    function setTargetGhoBoxAddress(address _ghoBox) external {
        if (msg.sender == _admin) {
            targetGhoBox = _ghoBox;
        }
    }

    // ==================== PUBLIC METHODS ====================

    /// @notice requests a borrow on the target chain, executes the borrow once request is fulfilled
    /// @param gCs Gho amount to borrow against current chain collateral
    /// @param gCt Gho amount to borrow against target chain collateral
    function requestBorrow(uint256 gCs, uint256 gCt) external {
        if (gCs == 0 && gCt == 0) revert ZeroAmount();

        uint32 ref = uint32(borrowRequests.length);
        borrowRequests.push(BorrowRequest(msg.sender, gCs, gCt, ref, false));

        if (gCs > 0 && gCt == 0) {
            // execute borrow immediately if target borrow amount is 0
            return _handleExecuteBorrow(abi.encode(ref));
        }

        // only request burn and notify if target borrow amoutn is > 0
        _ccipSend(
            abi.encode(
                OpCode.BURN_AND_NOTIFY, // operation op code
                abi.encode( // operation payload
                BurnAndNotifyMessage({user: msg.sender, amount: gCt, ref: ref}))
            )
        );

        emit BorrowRequested(msg.sender, gCs, gCt, ref);
    }

    // ==================== INTERNAL METHODS ====================

    /// @notice dispatches incoming CCIP messages to the appropriate handler
    /// @param _incomingMessage CCIP messages received from the outside world through the chainlink router
    function _ccipReceive(Client.Any2EVMMessage memory _incomingMessage)
        internal
        override
    {
        address sender = abi.decode(_incomingMessage.sender, (address));
        uint64 senderChainId = _incomingMessage.sourceChainSelector;
        // only accept messages from the target gho box
        if (sender != targetGhoBox || senderChainId != targetChainId) {
            revert InvalidSender();
        }

        (OpCode op, bytes memory rawData) =
            abi.decode(_incomingMessage.data, (OpCode, bytes)); // gas ??
        if (op == OpCode.BURN_AND_NOTIFY) {
            _handleBurnAndNotify(rawData);
        } else if (op == OpCode.EXECUTE_BORROW) {
            _handleExecuteBorrow(rawData);
        } else {
            revert InvalidOp();
        }
    }

    /// @notice borrows GHO on behalf of sender and burns it,
    /// then sends a CCIP message to the target chain to execute the pending borrow
    /// @param _burnAndNotifyMessageRawData raw data of the message
    function _handleBurnAndNotify(bytes memory _burnAndNotifyMessageRawData)
        internal
        returns (bytes32 ccipId)
    {
        BurnAndNotifyMessage memory _msg =
            abi.decode(_burnAndNotifyMessageRawData, (BurnAndNotifyMessage));

        IPool(pool).borrow(address(gho), _msg.amount, 2, 0, _msg.user); // lock GHO on mainnet
        // IGhoToken(gho).burn(_amount); because we are not whitelisted to burn yet

        ccipId =
            _ccipSend(abi.encode(OpCode.EXECUTE_BORROW, abi.encode(_msg.ref)));
        emit Mint(_msg.user, _msg.amount, ccipId);
    }

    /// @notice executes a pending borrow
    /// @param _executeBorrowRawData raw data of the message
    function _handleExecuteBorrow(bytes memory _executeBorrowRawData)
        internal
    {
        uint32 ref = abi.decode(_executeBorrowRawData, (uint32));
        BorrowRequest storage borrowRequest = borrowRequests[ref];

        if (borrowRequest.fulfilled) revert BorrowAlreadyFulfilled();
        borrowRequest.fulfilled = true;

        {
            address user = borrowRequest.user;
            uint256 gCs = borrowRequest.gCs;
            uint256 gCt = borrowRequest.gCt;
            uint256 total = gCs + gCt;
            address _gho = gho;

            IPool(pool).borrow(address(_gho), gCs, 2, 0, user);
            IGhoToken(mockGhoToken).mint(address(this), gCt); // using mockGho for minting
            IGhoToken(mockGhoToken).mint(address(this), gCs); // not needed if whitelisted as facilitator
            IERC20(mockGhoToken).safeTransfer(user, total);

            emit BorrowFulfilled(user, gCs, gCt, ref);
        }
    }

    /// @notice sends a CCIP message to the target chain
    /// @param rawData raw data to be sent to the target chain
    function _ccipSend(bytes memory rawData)
        internal
        returns (bytes32 ccipId)
    {
        uint64 _targetChainId = targetChainId;
        IERC20 _feeToken = IERC20(feeToken);
        IRouterClient _router = IRouterClient(router);

        Client.EVM2AnyMessage memory mintMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(targetGhoBox),
            data: rawData,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 100_0000})
                ),
            feeToken: address(_feeToken)
        });

        uint256 ccipFees = _router.getFee(_targetChainId, mintMessage);

        if (ccipFees > _feeToken.balanceOf(address(this))) {
            revert NotEnoughBalance(
                _feeToken.balanceOf(address(this)), ccipFees
            );
        }
        _feeToken.approve(address(_router), ccipFees); // allow chainlink router to take fees
        ccipId = _router.ccipSend(_targetChainId, mintMessage);
    }
}
