// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILinkFrost {
    function frost(address _to, uint256 amount) external;
}
