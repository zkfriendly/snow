// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Frost} from "../src/Frost.sol";
import {MockGho} from "../src/mocks/MockGho.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract FrostTest is Test {
    Frost public frost;
    MockGho public ghoToken;
    address public router = address(2);
    address snow = address(3);
    address alice = address(1);
    address bob = address(4);

    function setUp() public {
        ghoToken = new MockGho();
        frost = new Frost(address(ghoToken), router);
    }

    function test_Setup() public {
        assertEq(address(frost.GHO()), address(ghoToken));
    }

    function test_MintGho() public {
        Client.Any2EVMMessage memory frostSignal = Client.Any2EVMMessage({
            messageId: keccak256("frostSignal"),
            sourceChainSelector: 0,
            sender: abi.encode(snow),
            data: abi.encode(alice, uint256(100)),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectCall(address(ghoToken), abi.encodeWithSelector(ghoToken.mint.selector, alice, uint256(100)));
        vm.prank(router);
        frost.ccipReceive(frostSignal);
    }
}
