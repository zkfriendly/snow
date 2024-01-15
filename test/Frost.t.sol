// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Frost} from "../src/Frost.sol";
import {MockGho} from "../src/mocks/MockGho.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";

contract FrostTest is Test {
    Frost public frost;

    address public ghoToken = address(1);
    address public router = address(2);
    address public snow = address(3);
    address public linkToken = address(4);

    uint64 public sourceChainId = 1;

    function setUp() public {
        frost = new Frost(ghoToken, router, snow, linkToken, sourceChainId);
    }

    function test_Setup() public {
        assertEq(address(frost.gho()), address(ghoToken));
        assertEq(address(frost.router()), router);
        assertEq(frost.sourceChainId(), sourceChainId);
        assertEq(address(frost.feeToken()), linkToken);
        assertEq(address(frost.snow()), snow);
    }

    function testFuzz_MintGho(address alice, uint256 amount) public {
        vm.assume(alice != address(0));
        Client.Any2EVMMessage memory frostSignal = Client.Any2EVMMessage({
            messageId: keccak256("frostSignal"),
            sourceChainSelector: sourceChainId,
            sender: abi.encode(snow),
            data: abi.encode(alice, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.mockCall(ghoToken, abi.encodeWithSelector(IGhoToken.mint.selector, alice, amount), abi.encode(true));
        vm.expectCall(address(ghoToken), abi.encodeWithSelector(IGhoToken.mint.selector, alice, amount));
        vm.prank(router);
        frost.ccipReceive(frostSignal);
    }

    function testFuzz_BurnGho(address from, address to, uint256 amount) public {
        vm.assume(from != address(0));
        Client.EVM2AnyMessage memory thawSignal = Client.EVM2AnyMessage({
            receiver: abi.encode(snow), // ABI-encoded receiver address
            data: abi.encode(to, amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(linkToken)
        });
        vm.mockCall(router, abi.encodeWithSelector(IRouterClient.getFee.selector), abi.encode(10)); // set fee to 10
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(frost)), abi.encode(100)); // set balance to 100
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, router, 10), abi.encode(true));
        vm.mockCall(router, abi.encodeWithSelector(IRouterClient.ccipSend.selector), abi.encode(keccak256("thaw"))); // send thaw
        vm.mockCall(
            ghoToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(frost), amount),
            abi.encode(true)
        );
        vm.mockCall(ghoToken, abi.encodeWithSelector(IGhoToken.burn.selector, amount), abi.encode(true));

        vm.expectCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, router, 10));
        vm.expectCall(router, abi.encodeWithSelector(IRouterClient.ccipSend.selector, sourceChainId, thawSignal)); // send thaw
        vm.expectCall(
            address(ghoToken), abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(frost), amount)
        );
        vm.expectCall(address(ghoToken), abi.encodeWithSelector(IGhoToken.burn.selector, amount));
        vm.expectEmit(address(frost));
        emit Frost.Burn(to, amount, keccak256("thaw"));

        vm.prank(from);
        frost.thaw(to, amount);
    }
}
