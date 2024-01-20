// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {GhoBox} from "../src/GhoBox.sol";
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

contract MockCCIP is Script {
    GhoBox public ghoBox = GhoBox(0x65839AC8ED06ba60A7fa8E2989bC7cE9a1531502);
    uint64 public targetChainId = 16015286601757825753; // sepolia
    address public targetGhoBox = 0x43EDbC85169dC2601Cf5Fe1DbD07f5B55B60DA2c;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Client.Any2EVMMessage memory _incomingMessage = Client.Any2EVMMessage({
            messageId: keccak256("burnAndRemoteMint"),
            sourceChainSelector: targetChainId,
            sender: abi.encode(address(targetGhoBox)),
            data: abi.encode(
                IGhoBox.OpCode.BURN_AND_NOTIFY,
                abi.encode(0x743844f742168e0ace16E747745686bCC247146B, 4 ether, 0)
                ),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        ghoBox.ccipReceive(_incomingMessage);

        vm.stopBroadcast();
    }
}
