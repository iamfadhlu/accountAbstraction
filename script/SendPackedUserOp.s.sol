// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { PackedUserOperation } from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { IEntryPoint } from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script {

    using MessageHashUtils for bytes32;
    
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        address destination = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum mainnet USDC address
        address test = 0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC;
        address minimalAccount = 0x03Ad95a54f02A40180D45D76789C448024145aaF;
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, test, 1e18);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, functionData);
        PackedUserOperation memory userOp = generateSignedUserOperation(executeCallData, helperConfig.getConfig(), minimalAccount);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(userOps, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    /**
     * @notice Generate a signed user operation data
     * @param callData This is the callData to be used when calling the contract
     */
    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config, address minimalAccount) public view returns (PackedUserOperation memory) {

        // Generate an unsigned user data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory unsignedUserOp = _generateUnsignedUserOperation(callData, minimalAccount, nonce);

        // Get userOpHash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unsignedUserOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // Get it signed
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        }
        else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        unsignedUserOp.signature = abi.encodePacked(r, s, v);
        PackedUserOperation memory signedUserOp = unsignedUserOp;

        return signedUserOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce) internal pure returns (PackedUserOperation memory) {
        // Generate an unsigned user data
        uint256 verficationGasLimit = 16777216;
        uint256 callGasLimit = verficationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verficationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verficationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }

}