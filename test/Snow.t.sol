// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Snow} from "../src/Snow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract SnowTest is Test {
    Snow public snow;
    address public ghoToken = address(1);
    address public linkToken = address(2);
    address public linkFrost = address(3);
    address public tRouter = address(4);
    address public sRouter = address(5);
    uint64 public targetChainId = 2;

    function setUp() public {
        snow = new Snow(ghoToken, linkToken, linkFrost, sRouter, tRouter, targetChainId);
    }

    function test_Setup() public {
        assertEq(address(snow.GHO()), address(ghoToken));
        assertEq(address(snow.ROUTER()), tRouter);
        assertEq(snow.TARGET_CHAIN_ID(), targetChainId);
    }

    function testFuzz_Frost(address alice, uint256 amount) public {
        Client.EVM2AnyMessage memory frostSignal = Client.EVM2AnyMessage({
            receiver: abi.encode(linkFrost), // ABI-encoded receiver address
            data: abi.encode(alice, amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(linkToken)
        });

        vm.mockCall(
            ghoToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(snow), amount),
            abi.encode(true)
        ); // transferFrom 100

        vm.mockCall(tRouter, abi.encode(IRouterClient.getFee.selector), abi.encode(10)); // set fee to 10
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(snow)), abi.encode(100)); // set balance to 100
        vm.mockCall(
            linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(tRouter), uint256(10)), abi.encode(true)
        ); // approve 10
        vm.mockCall(tRouter, abi.encode(IRouterClient.ccipSend.selector), abi.encode(keccak256("forge"))); // send forge

        vm.expectCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(tRouter), uint256(10)));
        vm.expectCall(tRouter, abi.encodeWithSelector(IRouterClient.ccipSend.selector, targetChainId, frostSignal));
        vm.expectEmit(address(snow));
        emit Snow.Frost(alice, amount, keccak256("forge"));
        vm.prank(alice);
        snow.frost(alice, amount);
    }
}
