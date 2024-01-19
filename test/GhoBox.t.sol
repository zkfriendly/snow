// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GhoBox} from "../src/GhoBox.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from
    "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IGhoBox} from "../src/interfaces/IGhoBox.sol";
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
        vm.assume(_amount > 0);

        _mockAndExpectCcipSend(
            IGhoBox.OpCode.EXECUTE_BORROW,
            abi.encode(address(this), _amount, _ref)
        );
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
                IGhoBox.OpCode.BURN_AND_REMOTE_MINT,
                abi.encode(address(this), _amount, _ref)
                ),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(router);
        box.ccipReceive(_incomingMessage);
    }

    function test_requestBorrow(uint256 _gCs, uint256 _gCt) public {
        vm.assume(_gCs > 0 && _gCt > 0);

        _requestBorrow(_gCs, _gCt, 0);

        (address sender, uint256 gCs, uint256 gCt, uint32 ref, bool fulfilled) =
            box.borrowRequests(0);

        assertEq(sender, address(this));
        assertEq(gCs, _gCs);
        assertEq(gCt, _gCt);
        assertEq(ref, 0);
        assertEq(fulfilled, false);
    }

    function test_executesBorrow(uint256 _total, uint256 _gCs) public {
        vm.assume(_total > _gCs);
        uint256 _gCt = _total - _gCs;

        // first request a borrow
        uint32 _ref = 0;
        _requestBorrow(_gCs, _gCt, _ref);

        // send a ccip execute borrow message
        Client.Any2EVMMessage memory _incomingMessage = Client.Any2EVMMessage({
            messageId: keccak256("executeBorrow"),
            sourceChainSelector: targetChainId,
            sender: abi.encode(address(targetGhoBox)),
            data: abi.encode(IGhoBox.OpCode.EXECUTE_BORROW, abi.encode(_ref)),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        _mockAndExpect(
            ghoToken,
            abi.encodeWithSelector(IGhoToken.mint.selector, address(box), _gCt),
            abi.encode(true)
        );

        _mockAndExpect(
            pool,
            abi.encodeWithSelector(
                IPool.borrow.selector, ghoToken, _gCs, 2, 0, address(this)
            ),
            abi.encode(true)
        );

        _mockAndExpect(
            ghoToken,
            abi.encodeWithSelector(
                IERC20.transfer.selector, address(this), _gCs + _gCt
            ),
            abi.encode(true)
        );

        vm.prank(router);
        box.ccipReceive(_incomingMessage);

        // check that the borrow request has been fulfilled
        (,,,, bool fulfilled) = box.borrowRequests(_ref);

        assertEq(fulfilled, true);
    }

    function test_secondBorrowRequestIncrementsRef() public {
        _requestBorrow(1, 1, 0);
        _requestBorrow(1, 1, 1);
    }

    function _requestBorrow(uint256 _gCs, uint256 _gCt, uint32 _ref) internal {
        _mockAndExpectCcipSend(
            IGhoBox.OpCode.BURN_AND_REMOTE_MINT,
            abi.encode(address(this), _gCt, _ref)
        );
        box.requestBorrow(_gCs, _gCt);
    }

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

    function _mockAndExpectCcipSend(IGhoBox.OpCode opCode, bytes memory rawData)
        internal
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(targetGhoBox),
            data: abi.encode(opCode, rawData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            feeToken: address(linkToken)
        });

        // mock router.getFee
        bytes memory getFeeCall = abi.encodeWithSelector(
            IRouterClient.getFee.selector, targetChainId, message
        );
        bytes memory feeTokenBalanceOfCall =
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(box));
        bytes memory feeTokenApproveCall =
            abi.encodeWithSelector(IERC20.approve.selector, router, 10);
        bytes memory ccipSendCall = abi.encodeWithSelector(
            IRouterClient.ccipSend.selector, targetChainId, message
        );

        _mockAndExpect(router, getFeeCall, abi.encode(10));
        _mockAndExpect(linkToken, feeTokenBalanceOfCall, abi.encode(100));
        _mockAndExpect(linkToken, feeTokenApproveCall, abi.encode(true));
        _mockAndExpect(router, ccipSendCall, abi.encode(keccak256("msg")));
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
