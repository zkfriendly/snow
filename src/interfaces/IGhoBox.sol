// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoBox {
    enum OpCode {
        EXECUTE_BORROW,
        BURN_AND_NOTIFY
    }

    struct BurnAndNotifyMessage {
        address user;
        uint256 amount;
        uint32 ref;
    }

    struct BorrowRequest {
        address user; // user requesting the borrow
        uint256 gCs; // gho amount source chain
        uint256 gCt; // gho amount target chain
        uint32 ref; // unique identifier for this request
        bool fulfilled; // whether this request has been fulfilled
    }

    event Mint(address indexed to, uint256 amount, bytes32 ccipId); // GHO locked on mainnet, GHO minted on target chain
    event Burn(address indexed to, uint256 amount, bytes32 ccipId); // GHO burned on target chain, GHO unlocked on mainnet
    event BorrowRequested(
        address indexed user, uint256 gCs, uint256 gCt, uint32 ref
    );
    event BorrowFulfilled(
        address indexed user, uint256 gCs, uint256 gCt, uint32 ref
    );

    error NotEnoughBalance(uint256 balance, uint256 required);
    error FacilitatorAlreadySet(address facilitator);
    error InvalidSender();
    error InvalidOp();
    error BorrowAlreadyFulfilled();
}
