// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";
import {ICreditDelegationToken} from "@aave/v3/core/contracts/interfaces/ICreditDelegationToken.sol";

import "forge-std/Test.sol";

contract VirtualAccount is Ownable {
    using SafeERC20 for IERC20;

    address public immutable onBehalfOf;
    address public immutable pool;

    mapping(address => uint256) public balanceOf;

    error InvalidSender();

    constructor(address _pool, address _onBehalfOf, address _tToken, uint256 _tAmount) Ownable(msg.sender) {
        onBehalfOf = _onBehalfOf;
        pool = _pool;

        if (_tToken != address(0) && _tAmount > 0) {
            deposit(_tToken, _tAmount);
            // _supllyAsCollateral(_tToken, _tAmount);
        }
    }

    function supplyAsCollateral(address _token, uint256 _amount) external only(onBehalfOf) {
        _supllyAsCollateral(_token, _amount);
    }

    function removeCollateral(address _token, uint256 _amount) external only(onBehalfOf) {
        _removeCollateral(_token, _amount);
    }

    function approveDelegation(address debtAsset, address _delegatee, uint256 _amount) external only(onBehalfOf) {
        ICreditDelegationToken(debtAsset).approveDelegation(_delegatee, _amount);
    }

    function deposit(address _token, uint256 _amount) public {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_token, _amount);
    }

    function withdraw(address _token, address _to, uint256 _amount) public only(onBehalfOf) {
        IERC20(_token).safeTransfer(_to, _amount);
        _withdraw(_token, _amount);
    }

    function _deposit(address _token, uint256 _amount) internal {
        balanceOf[_token] += _amount;
    }

    function _withdraw(address _token, uint256 _amount) internal {
        balanceOf[_token] -= _amount;
    }

    function _supllyAsCollateral(address _token, uint256 _amount) internal {
        IERC20(_token).approve(pool, _amount);
        IPool(pool).supply(_token, _amount, address(this), 0);
        _withdraw(_token, _amount);
    }

    function _removeCollateral(address _token, uint256 _amount) internal {
        IPool(pool).withdraw(_token, _amount, address(this));
        _deposit(_token, _amount);
    }

    modifier only(address _address) {
        if (msg.sender != _address) {
            revert InvalidSender();
        }
        _;
    }
}
