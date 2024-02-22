// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SofamonWearables404.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SofamonWearablesTest is Test {
    using ECDSA for bytes32;

    event ProtocolFeeDestinationUpdated(address feeDestination);

    event ProtocolFeePercentUpdated(uint256 feePercent);

    event CreatorFeePercentUpdated(uint256 feePercent);

    event CreateSignerUpdated(address signer);

    event WearableCreated(
        address creator, bytes32 subject, string name, string template, string description, string imageURI
    );

    event Trade(
        address trader,
        bytes32 subject,
        bool isBuy,
        uint256 wearableAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 creatorEthAmount,
        uint256 supply
    );

    event WearableTransferred(address from, address to, bytes32 subject, uint256 amount);

    SofamonWearables public sofa;

    uint256 internal signer1Privatekey = 0x1;
    uint256 internal signer2Privatekey = 0x2;

    address owner = address(0x11);
    address protocolFeeDestination = address(0x22);
    address signer1 = vm.addr(signer1Privatekey);
    address signer2 = vm.addr(signer2Privatekey);
    address creator1 = address(0xa);
    address creator2 = address(0xb);
    address user1 = address(0xc);
    address user2 = address(0xd);

    function setUp() public {
        vm.prank(owner);
        sofa = new SofamonWearables(signer1);
    }

    function testSetProtocolFeeAndCreatorFee() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeePercentUpdated(0.05 ether);
        sofa.setProtocolFeePercent(0.05 ether);
        vm.expectEmit(true, true, true, true);
        emit CreatorFeePercentUpdated(0.05 ether);
        sofa.setCreatorFeePercent(0.05 ether);
        assertEq(sofa.protocolFeePercent(), 0.05 ether);
        assertEq(sofa.creatorFeePercent(), 0.05 ether);
    }

    function testSetProtocolFeeDestination() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeeDestinationUpdated(protocolFeeDestination);
        sofa.setProtocolFeeDestination(protocolFeeDestination);
        assertEq(sofa.protocolFeeDestination(), protocolFeeDestination);
    }

    function testSetSigner() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit CreateSignerUpdated(signer2);
        sofa.setCreateSigner(signer2);
        assertEq(sofa.createSigner(), signer2);
    }

    function testCreateWearable() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(signer1);
        bytes32 digest = keccak256(
            abi.encodePacked(creator1, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url")
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1Privatekey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(creator1);
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1, wearablesSubject, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url"
        );
        sofa.createWearable("test hoodie", "hoodie", "this is a test hoodie", "hoodie image url", signature);
        vm.stopPrank();
    }

    function testBuyWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(signer1);
        bytes32 digest = keccak256(
            abi.encodePacked(creator1, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url")
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1Privatekey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(creator1);
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1, wearablesSubject, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url"
        );
        sofa.createWearable("test hoodie", "hoodie", "this is a test hoodie", "hoodie image url", signature);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        uint256 buyPrice = sofa.getBuyPrice(wearablesSubject, 1 ether);
        uint256 buyPriceAfterFee = sofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
        uint256 protocolFeePercent = sofa.protocolFeePercent();
        uint256 creatorFeePercent = sofa.creatorFeePercent();
        vm.expectEmit(true, true, true, true);
        emit Trade(
            user1,
            wearablesSubject,
            true,
            1 ether,
            buyPrice,
            (buyPrice * protocolFeePercent) / 1 ether,
            (buyPrice * creatorFeePercent) / 1 ether,
            1 ether
        );
        // buy 1 full share of the wearable
        sofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);
    }

    function testSellWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(signer1);
        bytes32 digest = keccak256(
            abi.encodePacked(creator1, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url")
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1Privatekey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(creator1);
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1, wearablesSubject, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url"
        );
        sofa.createWearable("test hoodie", "hoodie", "this is a test hoodie", "hoodie image url", signature);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        // get price for 2 full share of the wearable
        uint256 buyPriceAfterFee = sofa.getBuyPriceAfterFee(wearablesSubject, 2 ether);
        sofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 2 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);
        assertEq(sofa.wearablesBalance(wearablesSubject, user1), 2 ether);

        uint256 sellPrice = sofa.getSellPrice(wearablesSubject, 1 ether);
        uint256 sellPriceAfterFee = sofa.getSellPriceAfterFee(wearablesSubject, 1 ether);
        uint256 protocolFeePercent = sofa.protocolFeePercent();
        uint256 creatorFeePercent = sofa.creatorFeePercent();
        vm.expectEmit(true, true, true, true);
        emit Trade(
            user1,
            wearablesSubject,
            false,
            1 ether,
            sellPrice,
            (sellPrice * protocolFeePercent) / 1 ether,
            (sellPrice * creatorFeePercent) / 1 ether,
            1 ether
        );
        sofa.sellWearables(wearablesSubject, 1 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee + sellPriceAfterFee);
        assertEq(sofa.wearablesBalance(wearablesSubject, user1), 1 ether);
    }

    function testTransferWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(signer1);
        bytes32 digest = keccak256(
            abi.encodePacked(creator1, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url")
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1Privatekey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();

        vm.startPrank(creator1);
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1, wearablesSubject, "test hoodie", "hoodie", "this is a test hoodie", "hoodie image url"
        );
        sofa.createWearable("test hoodie", "hoodie", "this is a test hoodie", "hoodie image url", signature);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        // get price for 3 full share of the wearable
        uint256 buyPriceAfterFee = sofa.getBuyPriceAfterFee(wearablesSubject, 3 ether);
        sofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 3 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);

        // transfer 1 full share of the wearable to user2
        vm.expectEmit(true, true, true, true);
        emit WearableTransferred(user1, user2, wearablesSubject, 1 ether);
        sofa.transferWearables(wearablesSubject, user1, user2, 1 ether);
        assertEq(sofa.wearablesBalance(wearablesSubject, user1), 2 ether);
        assertEq(sofa.wearablesBalance(wearablesSubject, user2), 1 ether);
    }
}
