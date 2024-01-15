# Snow: GHO Portal Facilitator Using Chainlink CCIP

## Overview

The `Snow` and `Frost` contracts are part of a cross-chain token facilitation system using Chainlink's Cross-Chain Interoperability Protocol (CCIP). These contracts are designed for managing the GHO token across different blockchain networks.

### Snow Contract

- **File**: `Snow.sol`
- **Author**: @zkfriendly
- **Mainnet Deployment**: The `Snow` contract is deployed on the Ethereum mainnet.
- **Purpose**: It interacts with the AAVE GHO Facilitator to lock GHO tokens on the Ethereum mainnet and facilitates cross-chain token transfers.

#### Key Features:

- **Frost**: Lock GHO tokens on the mainnet and send a CCIP message to mint GHO on the target chain.
- **Thaw**: Receive burn attestations from the target chain and release GHO tokens on the mainnet.

### Frost Contract

- **File**: `Frost.sol`
- **Author**: @zkfriendly
- **Target Chain Deployment**: The `Frost` contract is deployed on a target chain other than Ethereum mainnet.
- **Purpose**: It serves as a GHO Facilitator on the target chain, managing the minting and burning of GHO tokens.

#### Key Features:

- **Mint**: Receive CCIP messages from the source chain (Snow contract) to mint GHO tokens on the target chain.
- **Burn**: Burn GHO tokens on the target chain and send a CCIP message to the source chain to unlock the same amount of GHO.

## Technical Details

### Snow.sol

- **Solidity Version**: `^0.8.13`
- **Dependencies**:
  - Chainlink CCIP Contracts
  - OpenZeppelin ERC20 and SafeERC20
- **Events**:
  - `Frost(address indexed to, uint256 amount, bytes32 forgeId)`
  - `Thaw(address indexed to, uint256 amount, bytes32 forgeId)`
- **Errors**:
  - `NotEnoughBalance`
  - `FacilitatorAlreadySet`
  - `InvalidSender`

### Frost.sol

- **Solidity Version**: `^0.8.13`
- **Dependencies**:
  - Chainlink CCIP Contracts
  - OpenZeppelin ERC20 and SafeERC20
  - IGhoToken Interface
- **Events**:
  - `Mint(address indexed to, uint256 amount, bytes32 frostId)`
  - `Burn(address indexed to, uint256 amount, bytes32 thawId)`
- **Errors**:
  - `InvalidSender`
  - `NotEnoughBalance`

## Installation and Setup

To use these contracts, clone the repository and install dependencies using your preferred package manager.

## Contributing

Contributions are welcome. Please submit pull requests for any enhancements.

## License

These contracts are released under the MIT License.
