// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Facilitator} from "../src/Facilitator.sol";
import {MockGho} from "../src/mocks/MockGho.sol";

contract FacilitatorMumbaiDeployer is Script {
    address public linkToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address public ghoBox = 0x17798d86AFdAbc1010A95E2ae6DbaD187c89b55E;
    address public router = 0x1035CabC275068e0F4b745A29CEDf38E13aF41b1;
    uint64 public sourceChainId = 16015286601757825753;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        address ghoToken = 0x796778a6502405929135d6934E0d647723C6db11;
        new Facilitator(ghoToken, router, ghoBox, linkToken, sourceChainId);
        vm.stopBroadcast();
    }
}
