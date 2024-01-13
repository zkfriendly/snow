// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Wormhole} from "../src/Wormhole.sol";

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract WormholeTest is Test {
    Wormhole public wormhole;
    ERC20 public gho;
    uint64 public targetChainId = 2;
    address public router = address(3);

    function setUp() public {
        // gho = new ERC20("GHO", "GHO");
        // wormhole = new Wormhole(gho, router, targetChainId);
        console.log("wormhole: %s", address(wormhole));
    }

    function test_Increment() public {
        // console2.log("gho: %s", gho);
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
