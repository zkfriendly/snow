# GhoBox: Liquidity Unifier Without Shifting Collateral.

## Overview

GhoBox is a contract that simplifies managing liquidity across multiple blockchains without shifting collateral. Users provide liquidity to Aave on any chain and delegate borrowing power to GhoBox to allow it to manage loans on this liquidity. Through the Cross-Chain Interoperability Protocol (CCIP), GhoBox coordinates loans across different chains. It handles all steps – borrowing, burning, and minting GHO tokens – making it easier for users to use their assets on various chains without moving their collateral.

## How It Works: A Running Example

Consider Alice, who wants to leverage her assets across Ethereum and Polygon without moving her collateral. Here's how GhoBox helps her:

### Step 1: Supplying Liquidity to Aave

- **Alice’s Action**: Alice supplies liquidity to the Aave protocol on both Ethereum and Polygon.

### Step 2: Delegating Credit to GhoBox

- **Alice’s Action**: She delegates the credit for GHO borrowing to the GhoBox instance on Ethereum and Polygon.

### Step 3: Requesting a GHO Loan

- **Alice’s Action**: Alice needs a total of 1000 GHO. She decides to use 600 GHO against her Ethereum liquidity and 400 GHO against her Polygon liquidity.
- **Process**: She requests the loan via GhoBox on Ethereum, specifying the amounts from each chain.

### Step 4: Coordinating Loan Across Chains

- **GhoBox’s Role**: GhoBox on Ethereum coordinates with the GhoBox on Polygon for Alice's loan.

### Step 5: Loan Execution on Polygon

- **GhoBox’s Action**: GhoBox on Polygon takes out a 400 GHO loan and immediately burns it as part of the process.

### Step 6: Confirmation via CCIP

- **GhoBox’s Action**: GhoBox uses CCIP to confirm the burning of GHO on Polygon.

### Step 7: Minting and Loan Fulfillment on Ethereum

- **Final Action**: After confirmation, GhoBox on Ethereum mints the total 1000 GHO (including the 400 GHO from Polygon) for Alice.

### Conclusion

- **Outcome for Alice**: Alice now has 1000 GHO on Ethereum, using her combined liquidity from Ethereum and Polygon, without transferring her assets.

This example showcases GhoBox's capability in facilitating cross-chain liquidity management efficiently.

## Features

- Seamless liquidity aggregation across multiple chains without moving collateral.
- Credit delegation using GHO tokens.
- Cross-chain loan management via CCIP.
- Integration with Chainlink and Aave protocols for robust and secure operations.
