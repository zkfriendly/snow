// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Facilitator} from "../src/Facilitator.sol";
import {MockGho} from "../src/mocks/MockGho.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";
import {IGhoBoxOp} from "../src/interfaces/IFacilitatorOp.sol";

contract FacilitatorTest is Test {
    Facilitator public facilitator;

    address public ghoToken = address(1);
    address public router = address(2);
    address public ghoBox = address(3);
    address public linkToken = address(4);

    uint64 public sourceChainId = 1;

    function setUp() public {
        facilitator = new Facilitator(ghoToken, router, ghoBox, linkToken, sourceChainId);
    }

    function test_Setup() public {
        assertEq(address(facilitator.gho()), address(ghoToken));
        assertEq(address(facilitator.router()), router);
        assertEq(facilitator.sourceChainId(), sourceChainId);
        assertEq(address(facilitator.feeToken()), linkToken);
        assertEq(address(facilitator.ghoBox()), ghoBox);
    }

    function testFuzz_MintGho(address alice, uint256 amount) public {
        vm.assume(alice != address(0));
        Client.Any2EVMMessage memory mintMessage = Client.Any2EVMMessage({
            messageId: keccak256("frostSignal"),
            sourceChainSelector: sourceChainId,
            sender: abi.encode(ghoBox),
            data: abi.encode(IGhoBoxOp.Op.MINT, abi.encode(alice, amount)),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.mockCall(ghoToken, abi.encodeWithSelector(IGhoToken.mint.selector, alice, amount), abi.encode(true));
        vm.expectCall(address(ghoToken), abi.encodeWithSelector(IGhoToken.mint.selector, alice, amount));
        vm.prank(router);
        facilitator.ccipReceive(mintMessage);
    }

    function testFuzz_BurnGho(address from, address to, uint256 amount) public {
        vm.assume(from != address(0) && to != address(0));
        Client.EVM2AnyMessage memory burnSignal = Client.EVM2AnyMessage({
            receiver: abi.encode(ghoBox), // ABI-encoded receiver address
            data: abi.encode(IGhoBoxOp.Op.BURN, abi.encode(to, amount)), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(linkToken)
        });
        vm.mockCall(router, abi.encodeWithSelector(IRouterClient.getFee.selector), abi.encode(10)); // set fee to 10
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(facilitator)), abi.encode(100)); // set balance to 100
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, router, 10), abi.encode(true));
        vm.mockCall(router, abi.encodeWithSelector(IRouterClient.ccipSend.selector), abi.encode(keccak256("burn"))); // send thaw
        vm.mockCall(
            ghoToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(facilitator), amount),
            abi.encode(true)
        );
        vm.mockCall(ghoToken, abi.encodeWithSelector(IGhoToken.burn.selector, amount), abi.encode(true));

        vm.expectCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, router, 10));
        vm.expectCall(router, abi.encodeWithSelector(IRouterClient.ccipSend.selector, sourceChainId, burnSignal)); // send thaw
        vm.expectCall(
            address(ghoToken), abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(facilitator), amount)
        );
        vm.expectCall(address(ghoToken), abi.encodeWithSelector(IGhoToken.burn.selector, amount));
        vm.expectEmit(address(facilitator));
        emit Facilitator.Burn(to, amount, keccak256("burn"));

        vm.prank(from);
        facilitator.burn(to, amount);
    }
}
