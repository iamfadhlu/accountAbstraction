# Minimal Account Abstraction Wallet

A minimal implementation of ERC-4337 Account Abstraction for both Ethereum and zkSync chains, built with Foundry. This project demonstrates how to create smart contract wallets that can operate on both L1 (Ethereum) and L2 (zkSync) while maintaining consistent functionality.

## Features

### Ethereum Implementation (ERC-4337)
- Full ERC-4337 compliant smart contract wallet
- UserOperation validation and execution
- Signature verification using ECDSA
- Ownable access control for wallet management
- Gas fee abstraction through EntryPoint contract
- Support for batched transactions
- Pre-fund validation for gas payments

### zkSync Implementation
- Native zkSync account abstraction support
- Transaction validation and execution
- ECDSA signature verification
- System contract integration for nonce management
- Bootloader interaction for transaction processing
- Support for both ETH and token transfers

## Architecture

### Ethereum Components
- `MinimalAccount.sol`: Main smart wallet contract implementing IAccount interface
- `EntryPoint.sol`: Central contract managing UserOperation validation and execution
- `PackedUserOperation`: Optimized structure for transaction data

### zkSync Components
- `ZKMinimalAccount.sol`: zkSync-specific wallet implementation
- Integration with zkSync system contracts:
  - Nonce Holder
  - Bootloader
  - System Contract Caller


## Security Features

- Ownable access control
- ECDSA signature verification
- Nonce management for replay protection
- Gas fee validation
- System contract integration for zkSync

## Testing Coverage

The project includes extensive test coverage for both implementations:
- User operation validation
- Transaction execution
- Signature verification
- Access control
- Gas payment handling
- Error cases and edge conditions
