// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Snow} from "../src/Snow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract SnowTest is Test {
    Snow public snow;
    address public ghoToken = address(1);
    address public linkToken = address(2);
    address public linkFrost = address(3);
    address public tRouter = address(4);
    address public sRouter = address(5);
    uint64 public targetChainId = 2;

    function setUp() public {
        snow = new Snow(ghoToken, linkToken, linkFrost, sRouter, tRouter, targetChainId);
    }

    function test_Setup() public {
        assertEq(address(snow.GHO()), address(ghoToken));
        assertEq(address(snow.ROUTER()), tRouter);
        assertEq(snow.TARGET_CHAIN_ID(), targetChainId);
    }

    function testFuzz_Frost(address alice, uint256 amount) public {
        vm.mockCall(
            ghoToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(snow), amount),
            abi.encode(true)
        ); // transferFrom 100

        vm.mockCall(tRouter, abi.encode(IRouterClient.getFee.selector), abi.encode(10)); // set fee to 10
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(snow)), abi.encode(100)); // set balance to 100
        vm.mockCall(
            linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(tRouter), uint256(10)), abi.encode(true)
        ); // approve 10
        vm.mockCall(tRouter, abi.encode(IRouterClient.ccipSend.selector), abi.encode(keccak256("forge"))); // send forge

        vm.expectEmit(address(snow));
        vm.expectCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(tRouter), uint256(10)));

        emit Snow.Frost(address(this), amount, keccak256("forge"));

        vm.prank(alice);
        snow.frost(address(this), amount);
    }
}
