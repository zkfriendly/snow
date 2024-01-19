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

import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IGhoBox} from "../src/interfaces/IGhoBox.sol";

import {MockGho} from "../src/mocks/MockGho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GhoBoxSepoliaDeployer is Script {
    address public ghoToken = 0xc4bF5CbDaBE595361438F8c6a187bDc330539c60;
    address public ghoVToken = AaveV3SepoliaAssets.GHO_V_TOKEN;
    address public pool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address public linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public router = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public mockGhoToken = 0xBB3938E3cC97BBE495cE318a9f6a15B58EE8a7C9;
    uint64 public targetChainId = 12532609583862916517;

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

        ghoBox.setTargetGhoBoxAddress(address(this));

        console2.log("GhoBox initialized");

        ICreditDelegationToken(ghoVToken).approveDelegation(
            address(ghoBox), type(uint256).max
        );

        console2.log("Credit delegation approved");

        // transfer some link tokens
        IERC20(linkToken).transfer(address(ghoBox), 1 ether);

        console2.log("Link tokens transferred");

        ghoBox.requestBorrow(3000000000000000000, 4000000000000000000);

        console2.log("Borrow request sent");

        // fake response ccip receive

        Client.Any2EVMMessage memory _incomingMessage = Client.Any2EVMMessage({
            messageId: keccak256("executeBorrow"),
            sourceChainSelector: targetChainId,
            sender: abi.encode(address(this)),
            data: abi.encode(IGhoBox.OpCode.EXECUTE_BORROW, abi.encode(0)),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        ghoBox.ccipReceive(_incomingMessage);

        console2.log("Borrow executed");

        vm.stopBroadcast();
    }
}
