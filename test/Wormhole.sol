// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Snow} from "../src/Wormhole.sol";

contract WormholeTest is Test {
    Snow public wormhole;
    address public ghoToken = address(1);
    address public router = address(3);
    uint64 public targetChainId = 2;

    function setUp() public {
        wormhole = new Snow(ghoToken, router, targetChainId);
    }

    function test_Setup() public {
        assertEq(address(wormhole.GHO()), address(ghoToken));
        assertEq(address(wormhole.ROUTER()), router);
        assertEq(wormhole.TARGET_CHAIN_ID(), targetChainId);
    }
}
