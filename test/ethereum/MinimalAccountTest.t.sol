// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint, MessageHashUtils} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MinimalAccountTest is Test{

    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock USDC;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;
    address public randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimalAccount deployMinimalAccount = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployMinimalAccount.deployMinimalAccount();
        USDC = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }
 

    function testOwnerCanExecuteCommands() public {
        // Arrange
        uint256 startingBalance = address(minimalAccount).balance;
        address destination = address(USDC);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(destination, value, funcData);

        // Assert
        assertEq(0, startingBalance);
        assertEq(USDC.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address destination = address(USDC);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector));
        minimalAccount.execute(destination, value, funcData);
    }

    function testRecoverSignedOp() public {
        // Arrange
        address destination = address(USDC);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, funcData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        address entryPoint = helperConfig.getConfig().entryPoint;
        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    /**
     * @notice This test is to validate the userOps
     * 1. Sign userOps
     * 2. Validate userOps
     * 3. Assert return is correct
     */
    function testValidationOfUserOps() public {
        // Arrange
        address destination = address(USDC);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, funcData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        address entryPoint = helperConfig.getConfig().entryPoint;
        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 0.1 ether;

        // Act
        vm.prank(entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);

        // Assert
        assertEq(validationData, 0);
    }

    function testFunctionDataCanExecuteCommands() public {
        // Arrange
        address destination = address(USDC);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, funcData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        address entryPoint = helperConfig.getConfig().entryPoint;
        uint256 STARTINGBALANCE = 1 ether;

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp; 

        // Act
        vm.deal(address(minimalAccount), STARTINGBALANCE * 2);

        vm.prank(randomUser);
        IEntryPoint(entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        assertEq(USDC.balanceOf(address(minimalAccount)), AMOUNT);

    }
}