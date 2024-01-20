// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {GhoBox} from "../src/GhoBox.sol";
import {
    AaveV3Sepolia,
    AaveV3SepoliaAssets
} from "../lib/aave-address-book/src/AaveV3Sepolia.sol";

import {ICreditDelegationToken} from
    "@aave/v3/core/contracts/interfaces/ICreditDelegationToken.sol";
import {
    AaveV3Mumbai,
    AaveV3MumbaiAssets
} from "../lib/aave-address-book/src/AaveV3Mumbai.sol";

import {ICreditDelegationToken} from
    "@aave/v3/core/contracts/interfaces/ICreditDelegationToken.sol";

import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IGhoBox} from "../src/interfaces/IGhoBox.sol";

import {MockGho} from "../src/mocks/MockGho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GhoBoxSepoliaDeployer is Script {
    address public ghoToken = AaveV3SepoliaAssets.GHO_UNDERLYING;
    address public ghoVToken = AaveV3SepoliaAssets.GHO_V_TOKEN;
    address public pool = address(AaveV3Sepolia.POOL);

    address public linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public router = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public mockGhoToken;
    uint64 public targetChainId = 12532609583862916517; // mumbai

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        mockGhoToken = address(new MockGho());

        console2.log("Mock GHO token deployed at: ", address(mockGhoToken));

        GhoBox ghoBox = new GhoBox(
            ghoToken, pool, linkToken, router, targetChainId, mockGhoToken
        );
        console2.log("GhoBox deployed at: ", address(ghoBox));

        ICreditDelegationToken(ghoVToken).approveDelegation(
            address(ghoBox), type(uint256).max
        );

        console2.log("Credit delegation approved");

        // transfer some link tokens
        IERC20(linkToken).transfer(address(ghoBox), 2 ether);

        console2.log("Link tokens transferred");

        vm.stopBroadcast();
    }
}

contract GhoBoxMumbaiDeployer is Script {
    // we pretend this is ghoVToken on mumbai because gho does not exist in AAVE mumbai markets yet
    address public ghoToken = AaveV3MumbaiAssets.DAI_UNDERLYING;
    address public ghoVToken = AaveV3MumbaiAssets.DAI_V_TOKEN;
    address public pool = address(AaveV3Mumbai.POOL);

    address public linkToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address public router = 0x1035CabC275068e0F4b745A29CEDf38E13aF41b1;
    uint64 public targetChainId = 16015286601757825753; // sepolia
    address public targetGhoBox = 0xf6f6356535e15853e34c8a18a0F290c07936AF7f;
    address public mockGhoToken;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        mockGhoToken = address(new MockGho());

        console2.log("Mock GHO token deployed at: ", address(mockGhoToken));

        GhoBox ghoBox = new GhoBox(
            ghoToken, pool, linkToken, router, targetChainId, mockGhoToken
        );

        console2.log("GhoBox deployed at: ", address(ghoBox));

        ICreditDelegationToken(ghoVToken).approveDelegation(
            address(ghoBox), type(uint256).max
        );
        console2.log("Credit delegation approved");

        ghoBox.setTargetGhoBoxAddress(targetGhoBox);

        console2.log("Target GhoBox address set");

        // transfer some link tokens
        IERC20(linkToken).transfer(address(ghoBox), 2 ether);

        console2.log("Link tokens transferred");

        vm.stopBroadcast();
    }
}
