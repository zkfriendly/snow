// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/Test.sol";

contract VirtualAccount is Ownable {
    using SafeERC20 for IERC20;

    address public immutable onBehalfOf;
    mapping(address => uint256) public balanceOf;

    constructor(address _onBehalfOf, address _tToken, uint256 _tAmount) Ownable(msg.sender) {
        onBehalfOf = _onBehalfOf;

        console2.log(_tToken, _tAmount, address(this), msg.sender);

        if (_tToken != address(0) && _tAmount > 0) {
            console2.log("tranfering tokens");
            deposit(_tToken, _tAmount);
        }
    }

    function deposit(address _token, uint256 _amount) public {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        balanceOf[_token] += _amount;

        console2.log("balance", balanceOf[_token], _token);
    }

    function withdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
        balanceOf[_token] -= _amount;
    }
}
