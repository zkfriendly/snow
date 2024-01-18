// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {AaveV3Sepolia, AaveV3SepoliaAssets} from "../lib/aave-address-book/src/AaveV3Sepolia.sol";
import {IPoolDataProvider} from "@aave/v3/core/contracts/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "@aave/v3/core/contracts/interfaces/IPoolAddressesProvider.sol";
import {VirtualAccount} from "../src/VirtualAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AccountSepoliaDeployer is Script {
    IPoolAddressesProvider addrProvider = AaveV3Sepolia.POOL_ADDRESSES_PROVIDER;
    IPoolDataProvider dataProvider = IPoolDataProvider(addrProvider.getPoolDataProvider());
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address user = 0x743844f742168e0ace16E747745686bCC247146B;

    function setUp() public {}

    function run() public {
        address dai = AaveV3SepoliaAssets.DAI_UNDERLYING;
        address pool = address(AaveV3Sepolia.POOL);
        uint256 amount = 10000000000000000;
        VirtualAccount va = VirtualAccount(0xd764BAe2A84039D7620e268a4A87B02fdC06E375);

        vm.startBroadcast(deployerPrivateKey);
        // IERC20(dai).approve(address(va), amount);
        va.removeAndWithdrawCollateral(dai, amount);
        vm.stopBroadcast();
    }

    function deploy(address pool) internal {
        vm.startBroadcast(deployerPrivateKey);
        new VirtualAccount(pool, user);
        vm.stopBroadcast();
    }
}
