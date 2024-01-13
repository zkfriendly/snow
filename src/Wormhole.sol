// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract Wormhole {
    address public immutable GHO; // GHO token address
    IRouterClient public immutable ROUTER; // chainlink router address
    uint64 public immutable TARGET_CHAIN_ID; // target chain id

    constructor(address _GHO, address _ROUTER, uint64 _TARGET_CHAIN_ID) {
        GHO = _GHO;
        ROUTER = IRouterClient(_ROUTER);
        TARGET_CHAIN_ID = _TARGET_CHAIN_ID;
    }
}
