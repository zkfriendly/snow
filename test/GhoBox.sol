// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GhoBox} from "../src/GhoBox.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract GhoBoxTest is Test {
    GhoBox public box;
    address public ghoToken = address(1);
    address public linkToken = address(2);
    address public facilitator = address(3);
    address public router = address(4);
    uint64 public targetChainId = 2;

    function setUp() public {
        box = new GhoBox(ghoToken, linkToken, router, targetChainId);
        box.initialize(facilitator);
    }

    function test_Setup() public {
        assertEq(address(box.gho()), address(ghoToken));
        assertEq(address(box.router()), router);
        assertEq(box.targetChainId(), targetChainId);
    }

    function testFuzz_Frost(address alice, uint256 amount) public {
        Client.EVM2AnyMessage memory mintMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(facilitator), // ABI-encoded receiver address
            data: abi.encode(GhoBox.Op.MINT, abi.encode(alice, amount)), // ABI-encoded string
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
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(box), amount),
            abi.encode(true)
        ); // transferFrom 100

        vm.mockCall(router, abi.encode(IRouterClient.getFee.selector), abi.encode(10)); // set fee to 10
        vm.mockCall(linkToken, abi.encodeWithSelector(IERC20.balanceOf.selector, address(box)), abi.encode(100)); // set balance to 100
        vm.mockCall(
            linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(router), uint256(10)), abi.encode(true)
        ); // approve 10
        vm.mockCall(router, abi.encode(IRouterClient.ccipSend.selector), abi.encode(keccak256("forge"))); // send forge

        vm.expectCall(linkToken, abi.encodeWithSelector(IERC20.approve.selector, address(router), uint256(10)));
        vm.expectCall(router, abi.encodeWithSelector(IRouterClient.ccipSend.selector, targetChainId, mintMessage));
        vm.expectEmit(address(box));
        emit GhoBox.Mint(alice, amount, keccak256("forge"));
        vm.prank(alice);
        box.sendMintMessage(alice, amount);
    }
}
