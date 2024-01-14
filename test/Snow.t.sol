// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Snow} from "../src/Snow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WormholeTest is Test {
    Snow public snow;
    address public ghoToken = address(1);
    address public router = address(3);
    uint64 public targetChainId = 2;

    function setUp() public {
        snow = new Snow(ghoToken, router, targetChainId);
    }

    function test_Setup() public {
        assertEq(address(snow.GHO()), address(ghoToken));
        assertEq(address(snow.ROUTER()), router);
        assertEq(snow.TARGET_CHAIN_ID(), targetChainId);
    }

    function test_FrostIncreasesBalance() public {
        uint256 amount = 100;

        vm.mockCall(
            ghoToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(snow), amount),
            abi.encode(true)
        );

        snow.frost(address(this), amount);
    }
}
