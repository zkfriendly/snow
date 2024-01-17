// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {VirtualAccount} from "../src/VirtualAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Create2} from "../src/Create2.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";

contract AccountTest is Test {
    VirtualAccount account;
    Create2 create2 = new Create2();
    address onBehalfOf = address(1);
    address wEth = address(2);
    address dai = address(3);
    address pool = address(4);

    function setUp() public {
        account = new VirtualAccount(pool, onBehalfOf, address(0), 0);
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
        account = new VirtualAccount(pool, onBehalfOf, dai, 100);

        assertEq(account.balanceOf(dai), 100);
        assertEq(account.balanceOf(wEth), 0);
    }

    function test_supplyCollateral() public {
        _deposit(wEth, 100);
        _supplyCollateral(wEth, 20);
    }

    function test_supllyDecreasesBalance() public {
        _deposit(wEth, 100);
        _supplyCollateral(wEth, 20);
        assertEq(account.balanceOf(wEth), 80);
    }

    function test_removeCollateral() public {
        _deposit(wEth, 100);
        _supplyCollateral(wEth, 20);
        _removeCollateral(wEth, 10);
    }

    function test_removeCollateralIncreasesBalance() public {
        _deposit(wEth, 100);
        _supplyCollateral(wEth, 20);
        _removeCollateral(wEth, 10);
        assertEq(account.balanceOf(wEth), 90);
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

        vm.prank(onBehalfOf);
        account.withdraw(address(_token), _to, _amount);
    }

    function _supplyCollateral(address _token, uint256 _amount) internal {
        bytes memory _call = abi.encodeWithSelector(IPool.supply.selector, wEth, _amount, address(account), 0);

        vm.mockCall(pool, _call, abi.encode(true));
        vm.expectCall(pool, _call);

        vm.prank(onBehalfOf);
        account.supplyAsCollateral(_token, _amount);
    }

    function _removeCollateral(address _token, uint256 _amount) internal {
        bytes memory _call = abi.encodeWithSelector(IPool.withdraw.selector, wEth, _amount, address(account));

        vm.mockCall(pool, _call, abi.encode(true));
        vm.expectCall(pool, _call);

        vm.prank(onBehalfOf);
        account.removeCollateral(_token, _amount);
    }
}
