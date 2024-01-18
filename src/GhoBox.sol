// SPDX-License-Identifier: MIT

/// @title GhoBox: GHO Portal Using Chainlink CCIP
/// @author @zkfriendly
/// @notice The GhoBox contract exists on the mainnet. It can receive or borrow GHO through credit delegation and lock it.
/// A CCIP message is then sent to a facilitator on target chain, where GHO is minted.
/// @dev This contract is a work in progress and has not yet been audited.

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
import {IGhoBoxOp} from "./interfaces/IFacilitatorOp.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";

contract GhoBox is IGhoBoxOp, CCIPReceiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable gho;
    IPool public immutable pool; // aave v3 pool address
    IERC20 public immutable feeToken; // token used to pay for CCIP fees
    uint64 public immutable targetChainId; // chainlink specific chain id
    IRouterClient public immutable router; // chainlink router address
    address public targetGhoBox;

    event Mint(address indexed to, uint256 amount, bytes32 ccipId); // GHO locked on mainnet, GHO minted on target chain
    event Burn(address indexed to, uint256 amount, bytes32 ccipId); // GHO burned on target chain, GHO unlocked on mainnet

    error NotEnoughBalance(uint256 balance, uint256 required);
    error FacilitatorAlreadySet(address facilitator);
    error InvalidSender(
        bytes32 messageId, address sender, address expectedSender
    );

    /// @notice construct contract
    /// @param _gho GHO token address
    /// @param _pool aave v3 pool address
    /// @param _link we are choosing LINK as the fee token
    /// @param _router chainlink router address
    /// @param _targetChainId target chain id (where GHO is minted)
    constructor(
        address _gho,
        address _pool,
        address _link,
        address _router,
        uint64 _targetChainId
    ) CCIPReceiver(_router) {
        gho = IERC20(_gho);
        pool = IPool(_pool);
        feeToken = IERC20(_link);
        targetChainId = _targetChainId;
        router = IRouterClient(_router);
    }

    /// @notice set the target gho box address
    /// @param _ghoBox address of the target facilitator
    /// @dev can only be called once.
    function initialize(address _ghoBox) external {
        if (targetGhoBox != address(0)) {
            revert FacilitatorAlreadySet(targetGhoBox);
        }
        targetGhoBox = _ghoBox;
    }

    /// @notice takes in GHO or borrows it on behalf of sender and burns it, then sends a CCIP message to the target chain
    /// @param _amount amount of GHO to be burned and minted on the target chain
    function burnAndRemoteMint(uint256 _amount, bool isBorrow)
        external
        returns (bytes32 ccipId)
    {
        address _sender = msg.sender;
        ccipId = _sendMintMessage(_sender, _amount, 0);

        if (isBorrow) {
            pool.borrow(address(gho), _amount, 2, 0, msg.sender); // lock GHO on mainnet
        } else {
            gho.safeTransferFrom(_sender, address(this), _amount);
        }

        // todo: burn
        emit Mint(_sender, _amount, ccipId);
    }

    /// @notice sends a CCIP message to the target chain to mint GHO tokens
    /// @param _user recipient address on the target chain
    /// @param _amount amount of GHO to be minted on the target chain
    /// @param _refrence unique identifier for requester of this mint operation
    function _sendMintMessage(address _user, uint256 _amount, uint32 _refrence)
        internal
        returns (bytes32 ccipId)
    {
        IERC20 _feeToken = feeToken;
        uint64 _targetChainId = targetChainId;
        IRouterClient _router = router;

        Client.EVM2AnyMessage memory mintMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(targetGhoBox),
            data: abi.encode(Op.MINT, abi.encode(_user, _amount, _refrence)),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
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

    /// @notice Whenever the target chain facilitator burns GHO tokens on the target chain,
    /// it sends a CCIP message to this contract, with the amount of GHO burned, and a recipient address on mainnet.
    /// it then releases the same amount of GHO tokens here (mainnet) to the recipient address.
    /// @param burnMessage CCIP message sent by the target chain facilitator through the chainlink router
    function _handleBurnMessage(Client.Any2EVMMessage memory burnMessage)
        internal
    {
        address sender = abi.decode(burnMessage.sender, (address));
        // only accept messages from the target facilitator
        if (sender != targetGhoBox) {
            revert InvalidSender(burnMessage.messageId, sender, targetGhoBox);
        }
        (, bytes memory rawData) = abi.decode(burnMessage.data, (Op, bytes));
        (address to, uint256 amount) = abi.decode(rawData, (address, uint256));
        gho.safeTransfer(to, amount);
        emit Burn(to, amount, burnMessage.messageId);
    }

    /// @notice dispatches incoming CCIP messages to the appropriate handler
    /// @param _incomingMessage CCIP messages received from the outside world through the chainlink router
    function _ccipReceive(Client.Any2EVMMessage memory _incomingMessage)
        internal
        override
    {
        (Op op,) = abi.decode(_incomingMessage.data, (Op, bytes)); // gas ??
        if (op == Op.BURN) _handleBurnMessage(_incomingMessage);
        else revert InvalidOp();
    }
}
