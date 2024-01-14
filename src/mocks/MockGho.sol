// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MockGho is ERC20, ERC20Burnable {
    bytes32 public constant FACILITATOR_ROLE = keccak256("FACILITATOR_ROLE");

    constructor(address facilitator) ERC20("MOCK GHO", "mGHO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
