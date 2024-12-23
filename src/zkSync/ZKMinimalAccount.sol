// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount, Transaction, MemoryTransactionHelper} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import { SystemContractsCaller } from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import { NONCE_HOLDER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, DEPLOYER_SYSTEM_CONTRACT } from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import { Utils } from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";
import { INonceHolder } from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

contract ZKMinimalAccount is IAccount, Ownable {

    error ZKMinimalAccount__NotEnoughFundsToPayForTransaction();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZKMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZKMinimalAccount__PaymentToBootLoaderFailed();
    error ZKMinimalAccount__ValidationFailed();

    using MemoryTransactionHelper for Transaction;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Must increase the nonce
     * @notice Must validate the transaction (Check the owner signed the transaction)
     * @notice Also check if there are enough funds available to pay for the transaction
     */
    function validateTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external payable requireFromBootLoader returns (bytes4 magic){
        return _validateTransaction(_transaction);
    }

    function executeTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZKMinimalAccount__ValidationFailed();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32 /*_txHash*/, bytes32 /*_suggestedSignedHash*/, Transaction memory _transaction) external payable {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZKMinimalAccount__PaymentToBootLoaderFailed();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction) external payable {}


    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // To increase the nonce, a systems contract call has to be made
        // Call nonce holder
        // Increment nonce by 1
        // Sytem callers are used to make a call to the system contracts

        SystemContractsCaller.systemCallWithPropagatedRevert(uint32(gasleft()), address(NONCE_HOLDER_SYSTEM_CONTRACT), 0, abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce)));
        // This is a system call simulation as it makes a system contract call to the Nonce Holder contract

        // Check for fee to pay for the transaction
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZKMinimalAccount__NotEnoughFundsToPayForTransaction();
        }

        // Check if the transaction is signed by the owner
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidOwner = signer == owner();
        if (isValidOwner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }

        // Return the magic number
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;
        bool success;
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to , value, data);
        } else {
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZKMinimalAccount__ExecutionFailed();
            }
        }
    }

}