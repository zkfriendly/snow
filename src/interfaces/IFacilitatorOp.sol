// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGhoBoxOp {
    enum Op {
        BURN,
        MINT
    }

    error InvalidOp();
}
