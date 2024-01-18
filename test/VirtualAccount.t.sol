// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {VirtualAccount} from "../src/VirtualAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";
import {ICreditDelegationToken} from
    "@aave/v3/core/contracts/interfaces/ICreditDelegationToken.sol";

contract AccountTest is Test {
    VirtualAccount account;
    address onBehalfOf = address(1);
    address wEth = address(2);
    address dai = address(3);
    address pool = address(4);
    address debtAsset = address(5);

    function setUp() public {
        account = new VirtualAccount(pool, onBehalfOf);
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

    function test_delegatesCredit() public {
        bytes memory _call = abi.encodeWithSelector(
            ICreditDelegationToken.approveDelegation.selector,
            address(this),
            200
        );

        vm.mockCall(debtAsset, _call, abi.encode(true));
        vm.expectCall(debtAsset, _call);

        vm.prank(onBehalfOf);
        account.approveDelegation(debtAsset, address(this), 200);
    }

    function _deposit(address _token, uint256 _amount) internal {
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                address(this),
                address(account),
                _amount
            ),
            abi.encode(true)
        );

        vm.expectCall(
            wEth,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                address(this),
                address(account),
                _amount
            )
        );

        account.deposit(wEth, 100);
    }

    function _withdraw(address _token, address _to, uint256 _amount) internal {
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount),
            abi.encode(true)
        );
        vm.expectCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, _to, _amount)
        );

        vm.prank(onBehalfOf);
        account.withdraw(address(_token), _to, _amount);
    }

    function _supplyCollateral(address _token, uint256 _amount) internal {
        bytes memory approveCall =
            abi.encodeWithSelector(IERC20.approve.selector, pool, _amount);
        bytes memory supplyCall = abi.encodeWithSelector(
            IPool.supply.selector, wEth, _amount, address(account), 0
        );

        vm.mockCall(pool, supplyCall, abi.encode(true));
        vm.expectCall(pool, supplyCall);

        vm.mockCall(wEth, approveCall, abi.encode(true));
        vm.expectCall(wEth, approveCall);

        vm.prank(onBehalfOf);
        account.addCollateral(_token, _amount);
    }

    function _removeCollateral(address _token, uint256 _amount) internal {
        bytes memory _call = abi.encodeWithSelector(
            IPool.withdraw.selector, wEth, _amount, address(account)
        );

        vm.mockCall(pool, _call, abi.encode(true));
        vm.expectCall(pool, _call);

        vm.prank(onBehalfOf);
        account.removeCollateral(_token, _amount);
    }
}
