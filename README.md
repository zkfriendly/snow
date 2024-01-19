# GhoBox

## Overview

GhoBox is a contract that simplifies managing liquidity across multiple blockchains without shifting collateral. Users provide liquidity to Aave on any chain and delegate borrowing power to GhoBox to allow it to manage loans on this liquidity. Through the Cross-Chain Interoperability Protocol (CCIP), GhoBox coordinates loans across different chains. It handles all steps – borrowing, burning, and minting GHO tokens – making it easier for users to use their assets on various chains without moving their collateral.

## How It Works

Here's a step-by-step breakdown of how GhoBox operates:

### 1. Supplying Liquidity to Aave

- **Users' Action**: Users supply liquidity to the Aave protocol on any blockchain of their choice.

### 2. Delegating Credit to GhoBox

- **Users' Action**: Users delegate the credit for GHO lending to a GhoBox instance on each chain where they have assets.

### 3. Requesting a GHO Loan

- **Users' Action**: Users can request a GHO loan from any supported blockchain.
- **Details**: When making a loan request, users specify the total amount of GHO they need and the amount they want to borrow from each chain.

### 4. Coordinating Loan Across Chains

- **GhoBox's Role**: Upon receiving a loan request, GhoBox coordinates with other GhoBox instances on the source chains.
- **Process**: Each GhoBox instance on the source chains takes out the specified GHO loan and immediately burns it.

### 5. Confirmations and Loan Fulfillment

- **Cross-Chain Communication**: GhoBox uses the Cross-Chain Interoperability Protocol (CCIP) to receive confirmations of the GHO burning from the source chains.
- **Final Step**: After receiving these confirmations, GhoBox mints an equal amount of GHO on the chain where the loan was requested, completing the loan process.

## Features

- Seamless liquidity aggregation across multiple chains without moving collateral.
- Credit delegation using GHO tokens.
- Cross-chain loan management via CCIP.
- Integration with Chainlink and Aave protocols for robust and secure operations.
