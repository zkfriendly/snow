// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {AaveV3Sepolia, AaveV3SepoliaAssets} from "../lib/aave-address-book/src/AaveV3Sepolia.sol";
import {IPoolDataProvider} from "@aave/v3/core/contracts/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "@aave/v3/core/contracts/interfaces/IPoolAddressesProvider.sol";

contract GhoBoxSepoliaDeployer is Script {
    function setUp() public {}

    function run() public {
        IPoolAddressesProvider addrProvider = AaveV3Sepolia.POOL_ADDRESSES_PROVIDER;

        IPoolDataProvider dataProvider = IPoolDataProvider(addrProvider.getPoolDataProvider());
        address user = 0x743844f742168e0ace16E747745686bCC247146B;
        address dai = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
        address vGho = AaveV3SepoliaAssets.GHO_V_TOKEN;
        address gho = AaveV3SepoliaAssets.GHO_UNDERLYING;
        {
            (
                uint256 currentATokenBalance,
                uint256 currentStableDebt,
                uint256 currentVariableDebt,
                uint256 principalStableDebt,
                uint256 scaledVariableDebt,
                uint256 stableBorrowRate,
                uint256 liquidityRate,
                uint40 stableRateLastUpdated,
                bool usageAsCollateralEnabled
            ) = dataProvider.getUserReserveData(gho, user);

            console2.log("currentATokenBalance", currentATokenBalance);
            console2.log("currentStableDebt", currentStableDebt);
            console2.log("currentVariableDebt", currentVariableDebt);
            console2.log("principalStableDebt", principalStableDebt);
            console2.log("scaledVariableDebt", scaledVariableDebt);
            console2.log("stableBorrowRate", stableBorrowRate);
            console2.log("liquidityRate", liquidityRate);
            console2.log("stableRateLastUpdated", stableRateLastUpdated);
            console2.log("usageAsCollateralEnabled", usageAsCollateralEnabled);
        }

        console2.log("====================================");

        {
            (
                uint256 totalCollateralBase,
                uint256 totalDebtBase,
                uint256 availableBorrowsBase,
                uint256 currentLiquidationThreshold,
                uint256 ltv,
                uint256 healthFactor
            ) = AaveV3Sepolia.POOL.getUserAccountData(user);
            console2.log("totalCollateralBase", totalCollateralBase);
            console2.log("totalDebtBase", totalDebtBase);
            console2.log("availableBorrowsBase", availableBorrowsBase);
            console2.log("currentLiquidationThreshold", currentLiquidationThreshold);
            console2.log("ltv", ltv);
            console2.log("healthFactor", healthFactor);
        }
    }
}
