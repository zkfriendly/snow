// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {VirtualAccount} from "../src/VirtualAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Create2} from "../src/Create2.sol";

contract AccountTest is Test {
    VirtualAccount account;
    Create2 create2 = new Create2();
    address onBehalfOf = address(1);
    address wEth = address(2);
    address dai = address(3);

    function setUp() public {
        account = new VirtualAccount(onBehalfOf, address(0), 0);
    }

    function test_setUp() public {
        assertEq(account.owner(), address(this));
        assertEq(account.onBehalfOf(), onBehalfOf);
    }

    function test_transfersTokenOnDepsit() public {
        _deposit(wEth, 100);
    }

    function test_increasesBalanceAfterDeposit() public {
        _deposit(wEth, 100);
        assertEq(account.balanceOf(wEth), 100);
    }

    function test_transfersOnWithdraw() public {
        _deposit(wEth, 100);
        _withdraw(wEth, address(this), 100);
    }

    function test_decreasesBalanceAfterWithdraw() public {
        _deposit(wEth, 100);
        _withdraw(wEth, address(this), 40);
        assertEq(account.balanceOf(wEth), 60);
    }

    function test_hasInitialTransfer() public {
        vm.mockCall(dai, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(dai, abi.encodeWithSelector(IERC20.transferFrom.selector));
        account = new VirtualAccount(onBehalfOf, dai, 100);

        assertEq(account.balanceOf(dai), 100);
        assertEq(account.balanceOf(wEth), 0);
    }

    function _deposit(address _token, uint256 _amount) internal {
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(account), _amount),
            abi.encode(true)
        );

        vm.expectCall(
            wEth, abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(account), _amount)
        );

        account.deposit(wEth, 100);
    }

    function _withdraw(address _token, address _to, uint256 _amount) internal {
        vm.mockCall(address(_token), abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount), abi.encode(true));
        vm.expectCall(address(_token), abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount));

        account.withdraw(address(_token), _to, _amount);
    }
}
