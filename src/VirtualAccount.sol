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

    address public immutable onBehalfOf; // user address
    address public immutable pool; // aave v3 pool address

    mapping(address => uint256) public balanceOf; // token address => withdrawable balance

    error InvalidSender();

    /// @notice construct contract with initial deposit and supply as collateral
    /// @param _pool aave v3 pool address
    /// @param _onBehalfOf user address
    constructor(address _pool, address _onBehalfOf) Ownable(msg.sender) {
        onBehalfOf = _onBehalfOf;
        pool = _pool;
    }

    // ==================== PUBLIC METHODS ====================

    /// @notice supply token as collateral into Aave v3 pool from the virtual account
    /// @param _token token address
    /// @param _amount amount to supply
    function addCollateral(address _token, uint256 _amount) external only(onBehalfOf) {
        _addCollateral(_token, _amount);
    }

    /// @notice remove token as collateral from Aave v3 pool into the virtual account
    /// @param _token token address
    /// @param _amount amount to remove
    /// @dev could fail if the position is undercollateralized
    function removeCollateral(address _token, uint256 _amount) external only(onBehalfOf) {
        _removeCollateral(_token, _amount);
    }

    /// @notice transfer asset from user directly to Aave v3 pool and supply as collateral
    /// @param _token token address
    /// @param _amount amount to deposit
    function depositAsCollateral(address _token, uint256 _amount) public {
        deposit(_token, _amount);
        _addCollateral(_token, _amount);
    }

    /// @notice remove collateral from Aave v3 pool and transfer to user directly
    /// @param _token token address
    /// @param _amount amount to withdraw
    function removeAndWithdrawCollateral(address _token, uint256 _amount) public {
        _removeCollateral(_token, _amount);
        withdraw(_token, msg.sender, _amount);
    }

    /// @notice deposit token to the virtual account
    /// @param _token token address - only aaave v3 tokens are supported
    /// @param _amount amount to deposit
    function deposit(address _token, uint256 _amount) public {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(_token, _amount);
    }

    /// @notice withdraw token from the virtual account
    /// @param _token token address
    /// @param _to address to receive the token
    function withdraw(address _token, address _to, uint256 _amount) public only(onBehalfOf) {
        IERC20(_token).safeTransfer(_to, _amount);
        _withdraw(_token, _amount);
    }

    /// @notice approve delegation of any debt token to any address
    /// @param debtAsset debt token address
    /// @param _delegatee address to delegate to
    function approveDelegation(address debtAsset, address _delegatee, uint256 _amount) external only(onBehalfOf) {
        ICreditDelegationToken(debtAsset).approveDelegation(_delegatee, _amount);
    }

    // ==================== internal functions ====================

    /// @notice increase internal balance
    /// @param _token token address
    /// @param _amount amount to increase
    function _deposit(address _token, uint256 _amount) internal {
        balanceOf[_token] += _amount;
    }

    /// @notice decrease internal balance
    /// @param _token token address
    /// @param _amount amount to decrease
    function _withdraw(address _token, uint256 _amount) internal {
        balanceOf[_token] -= _amount;
    }

    /// @notice supply token as collateral into Aave v3 pool
    /// @param _token token address
    /// @param _amount amount to supply
    function _addCollateral(address _token, uint256 _amount) internal {
        IERC20(_token).approve(pool, _amount);
        IPool(pool).supply(_token, _amount, address(this), 0);
        _withdraw(_token, _amount);
    }

    /// @notice remove token as collateral from Aave v3 pool
    /// @param _token token address
    /// @param _amount amount to remove
    function _removeCollateral(address _token, uint256 _amount) internal {
        IPool(pool).withdraw(_token, _amount, address(this));
        _deposit(_token, _amount);
    }

    // ==================== modifiers ====================

    modifier only(address _address) {
        if (msg.sender != _address) {
            revert InvalidSender();
        }
        _;
    }
}
