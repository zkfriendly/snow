// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IGhoToken} from "./interfaces/IGhoToken.sol";
import "forge-std/Test.sol";

contract Frost is CCIPReceiver {
    IGhoToken public immutable GHO; // GHO token address

    error duplicateMessage(bytes32 messageId);

    constructor(address _gho, address _router) CCIPReceiver(_router) {
        GHO = IGhoToken(_gho);
    }

    function _ccipReceive(Client.Any2EVMMessage memory frostSignal) internal override {
        (address to, uint256 amount) = abi.decode(frostSignal.data, (address, uint256));
        GHO.mint(to, amount);
    }
}
