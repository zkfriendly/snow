// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Snow} from "../src/Snow.sol";

contract SnowSepoliaDeployer is Script {
    address public ghoToken = 0xc4bF5CbDaBE595361438F8c6a187bDc330539c60;
    address public linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public router = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    uint64 public targetChainId = 12532609583862916517;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        Snow snow = new Snow(ghoToken, linkToken, router, targetChainId);
        console2(address(snow));
        vm.stopBroadcast();
    }
}
