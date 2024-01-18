// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GhoBox} from "../src/GhoBox.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IGhoBoxOp} from "../src/interfaces/IFacilitatorOp.sol";
import {IGhoToken} from "../src/interfaces/IGhoToken.sol";
import {IPool} from "@aave/v3/core/contracts/interfaces/IPool.sol";

contract GhoBoxTest is Test {
    GhoBox public box;
    address public ghoToken = address(1);
    address public linkToken = address(2);
    address public targetGhoBox = address(3);
    address public router = address(4);
    address public pool = address(5);
    uint64 public targetChainId = 2;
    uint64 public sourceChainId = 3;

    function setUp() public {
        box = new GhoBox(ghoToken, pool, linkToken, router, targetChainId);
        box.initialize(targetGhoBox);
    }

    function test_Setup() public {
        assertEq(address(box.gho()), address(ghoToken));
        assertEq(address(box.router()), router);
        assertEq(box.targetChainId(), targetChainId);
    }

    function test_borrowAndBurnRef(uint256 _amount, uint32 _ref) public {
        _mockMintMessageCcip(address(this), _amount, _ref);
        _mockGhoIntake(_amount, true);
        _mockAndExpect(
            ghoToken,
            abi.encodeWithSelector(IGhoToken.burn.selector, _amount),
            abi.encode(true)
        );

        Client.Any2EVMMessage memory _incomingMessage = Client.Any2EVMMessage({
            messageId: keccak256("burnAndRemoteMint"),
            sourceChainSelector: targetChainId,
            sender: abi.encode(address(targetGhoBox)),
            data: abi.encode(
                IGhoBoxOp.OpCode.BURN_AND_REMOTE_MINT,
                abi.encode(address(this), _amount, _ref)
                ),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(router);
        box.ccipReceive(_incomingMessage);
    }

    function test_requestBorrow() public {}

    function _mockGhoIntake(uint256 _amount, bool _isBorrow) internal {
        if (_isBorrow) {
            _mockAndExpect(
                pool,
                abi.encodeWithSelector(
                    IPool.borrow.selector,
                    ghoToken,
                    _amount,
                    2,
                    0,
                    address(this)
                ),
                abi.encode(true)
            );
        } else {
            _mockAndExpect(
                ghoToken,
                abi.encodeWithSelector(
                    IERC20.transferFrom.selector,
                    address(this),
                    address(box),
                    _amount
                ),
                abi.encode(true)
            );
        }
    }

    function _mockMintMessageCcip(
        address _user,
        uint256 _amount,
        uint32 _refrence
    ) internal {
        Client.EVM2AnyMessage memory mintMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(targetGhoBox),
            data: abi.encode(
                IGhoBoxOp.OpCode.MINT, abi.encode(_user, _amount, _refrence)
                ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            feeToken: address(linkToken)
        });

        // mock router.getFee
        bytes memory getFeeCall = abi.encodeWithSelector(
            IRouterClient.getFee.selector, targetChainId, mintMessage
        );
        bytes memory feeTokenBalanceOfCall =
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(box));
        bytes memory feeTokenApproveCall =
            abi.encodeWithSelector(IERC20.approve.selector, router, 10);
        bytes memory ccipSendCall = abi.encodeWithSelector(
            IRouterClient.ccipSend.selector, targetChainId, mintMessage
        );

        _mockAndExpect(router, getFeeCall, abi.encode(10));
        _mockAndExpect(linkToken, feeTokenBalanceOfCall, abi.encode(100));
        _mockAndExpect(linkToken, feeTokenApproveCall, abi.encode(true));
        _mockAndExpect(router, ccipSendCall, abi.encode(keccak256("mint")));
    }

    function _mockAndExpect(
        address _target,
        bytes memory _call,
        bytes memory _ret
    ) internal {
        vm.mockCall(_target, _call, _ret);
        vm.expectCall(_target, _call);
    }
}
