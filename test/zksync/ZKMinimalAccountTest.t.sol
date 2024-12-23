// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZKMinimalAccount} from "src/zkSync/ZKMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import { BOOTLOADER_FORMAL_ADDRESS } from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import { ACCOUNT_VALIDATION_SUCCESS_MAGIC } from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

contract ZKMinimalAccountTest is Test, ZkSyncChainChecker {
    ZKMinimalAccount minimalAccount;
    ERC20Mock token;
    uint256 amount = 1e18;
    bytes32 constant EMPTY_BYTES = bytes32(0);
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
       minimalAccount = new ZKMinimalAccount();
       minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
       token = new ERC20Mock();
       vm.deal(address(minimalAccount), amount);
    }

    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address destination = address(token);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), amount);
        Transaction memory transaction = _createUnsignedTransaction(address(minimalAccount.owner()), 113, destination, value, funcData);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES, EMPTY_BYTES, transaction);

        // Assert
        assertEq(token.balanceOf(address(minimalAccount)), amount);
    }

    function testZkValidateTransaction() public {
        // Arrange
        address destination = address(token);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), amount);
        Transaction memory transaction = _createUnsignedTransaction(address(minimalAccount.owner()), 113, destination, value, funcData);
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EMPTY_BYTES, EMPTY_BYTES, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/
    function _createUnsignedTransaction(address from, uint8 txType, address to, uint256 value, bytes memory data) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: txType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216, 
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value, 
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""

        });
    }

    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 digest = MemoryTransactionHelper.encodeHash(transaction);
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v);
        return signedTransaction;

    }
}