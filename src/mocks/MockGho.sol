// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockGho is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant FACILITATOR_ROLE = keccak256("MINTER_ROLE");

    constructor(address facilitator) ERC20("MOCK GHO", "mGHO") {
        _grantRole(FACILITATOR_ROLE, facilitator);
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyRole(FACILITATOR_ROLE) {
        _mint(to, amount);
    }
}
