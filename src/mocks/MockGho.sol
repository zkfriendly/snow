// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockGho {
    mapping(address => uint256) public _balances;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }

    function burn(address from, uint256 amount) external {
        _balances[from] -= amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        returns (bool)
    {
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }
}
