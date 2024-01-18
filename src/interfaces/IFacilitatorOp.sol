// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoBoxOp {
    enum OpCode {
        BURN,
        MINT,
        BURN_AND_REMOTE_MINT
    }

    struct MintMessage {
        address user;
        uint256 amount;
        uint32 ref;
    }

    error InvalidOp();
}
