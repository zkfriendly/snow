// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Frost} from "../src/Frost.sol";
import {MockGho} from "../src/mocks/MockGho.sol";

contract FrostMumbaiDeployer is Script {
    address public linkToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address public snow = 0xf4C4821434c0B54Dd0c45953A8fF38f6D15c2166;
    address public router = 0x1035CabC275068e0F4b745A29CEDf38E13aF41b1;
    uint64 public sourceChainId = 16015286601757825753;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        MockGho ghoToken = new MockGho();
        new Frost(address(ghoToken), router, snow, linkToken, sourceChainId);
        vm.stopBroadcast();
    }
}
