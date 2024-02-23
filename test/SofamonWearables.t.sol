// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {TestBlast} from "../test/TestBlast.sol";

contract SofamonWearablesTest is Test {
    using ECDSA for bytes32;

    event ProtocolFeeDestinationUpdated(address feeDestination);

    event ProtocolFeePercentUpdated(uint256 feePercent);

    event CreatorFeePercentUpdated(uint256 feePercent);

    event CreateSignerUpdated(address signer);

    event WearableSaleStateUpdated(bytes32 wearablesSubject, SofamonWearables.SaleStates saleState);

    event WearableCreated(
        address creator,
        bytes32 subject,
        string name,
        string category,
        string description,
        string imageURI,
        uint256 curveAdjustmentFactor,
        SofamonWearables.SaleStates state
    );

    event Trade(
        address trader,
        bytes32 subject,
        bool isBuy,
        bool isPublic,
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

    address BLAST = 0x4300000000000000000000000000000000000002;

    address owner = address(0x11);
    address protocolFeeDestination = address(0x22);
    address signer1 = vm.addr(signer1Privatekey);
    address signer2 = vm.addr(signer2Privatekey);
    address creator1 = address(0xa);
    address creator2 = address(0xb);
    address user1 = address(0xc);
    address user2 = address(0xd);

    function setUp() public {
        TestBlast testBlast = new TestBlast();
        vm.etch(BLAST, address(testBlast).code);
        vm.prank(owner);
        sofa = new SofamonWearables(owner, signer1);
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PUBLIC
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
        vm.stopPrank();
    }

    function testSetWearableSalesState() public {
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PUBLIC
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WearableSaleStateUpdated(wearablesSubject, SofamonWearables.SaleStates.PRIVATE);
        sofa.setWearableSalesState(wearablesSubject, SofamonWearables.SaleStates.PRIVATE);
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PUBLIC
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
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

    function testBuyPrivateWearablesFailed() public {
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PRIVATE
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: false,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        uint256 buyPriceAfterFee = sofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
        vm.expectRevert(bytes4(keccak256("InvalidSaleState()")));
        sofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether);
    }

    function testBuyPrivateWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));
        {
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
                creator1,
                wearablesSubject,
                "test hoodie",
                "hoodie",
                "this is a test hoodie",
                "hoodie image url",
                50000,
                SofamonWearables.SaleStates.PRIVATE
            );
            sofa.createWearable(
                SofamonWearables.CreateWearableParams({
                    name: "test hoodie",
                    category: "hoodie",
                    description: "this is a test hoodie",
                    imageURI: "hoodie image url",
                    isPublic: false,
                    curveAdjustmentFactor: 50000,
                    signature: signature
                })
            );
            vm.stopPrank();
        }

        {
            vm.startPrank(signer1);
            bytes32 digest2 =
                keccak256(abi.encodePacked(user1, "buy", wearablesSubject, uint256(1 ether))).toEthSignedMessageHash();
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signer1Privatekey, digest2);
            bytes memory signature2 = abi.encodePacked(r2, s2, v2);
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
                false,
                1 ether,
                buyPrice,
                (buyPrice * protocolFeePercent) / 1 ether,
                (buyPrice * creatorFeePercent) / 1 ether,
                1 ether
            );
            // buy 1 full share of the wearable
            sofa.buyPrivateWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether, signature2);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee);
        }
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PUBLIC
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
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
            true,
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

    function testSellPrivateWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));
        {
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
                creator1,
                wearablesSubject,
                "test hoodie",
                "hoodie",
                "this is a test hoodie",
                "hoodie image url",
                50000,
                SofamonWearables.SaleStates.PRIVATE
            );
            sofa.createWearable(
                SofamonWearables.CreateWearableParams({
                    name: "test hoodie",
                    category: "hoodie",
                    description: "this is a test hoodie",
                    imageURI: "hoodie image url",
                    isPublic: false,
                    curveAdjustmentFactor: 50000,
                    signature: signature
                })
            );
            vm.stopPrank();
        }

        uint256 buyPriceAfterFee = sofa.getBuyPriceAfterFee(wearablesSubject, 2 ether);

        {
            vm.startPrank(signer1);
            bytes32 digest2 =
                keccak256(abi.encodePacked(user1, "buy", wearablesSubject, uint256(2 ether))).toEthSignedMessageHash();
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signer1Privatekey, digest2);
            bytes memory signature2 = abi.encodePacked(r2, s2, v2);
            vm.stopPrank();

            vm.startPrank(user1);
            vm.deal(user1, 1 ether);
            assertEq(user1.balance, 1 ether);
            // get price for 2 full share of the wearable
            sofa.buyPrivateWearables{value: buyPriceAfterFee}(wearablesSubject, 2 ether, signature2);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee);
            assertEq(sofa.wearablesBalance(wearablesSubject, user1), 2 ether);
            vm.stopPrank();
        }

        {
            vm.startPrank(signer1);
            bytes32 digest3 =
                keccak256(abi.encodePacked(user1, "sell", wearablesSubject, uint256(1 ether))).toEthSignedMessageHash();
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(signer1Privatekey, digest3);
            bytes memory signature3 = abi.encodePacked(r3, s3, v3);
            vm.stopPrank();

            vm.startPrank(user1);
            uint256 sellPrice = sofa.getSellPrice(wearablesSubject, 1 ether);
            uint256 sellPriceAfterFee = sofa.getSellPriceAfterFee(wearablesSubject, 1 ether);
            uint256 protocolFeePercent = sofa.protocolFeePercent();
            uint256 creatorFeePercent = sofa.creatorFeePercent();
            vm.expectEmit(true, true, true, true);
            emit Trade(
                user1,
                wearablesSubject,
                false,
                false,
                1 ether,
                sellPrice,
                (sellPrice * protocolFeePercent) / 1 ether,
                (sellPrice * creatorFeePercent) / 1 ether,
                1 ether
            );
            sofa.sellPrivateWearables(wearablesSubject, 1 ether, signature3);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee + sellPriceAfterFee);
            assertEq(sofa.wearablesBalance(wearablesSubject, user1), 1 ether);
            vm.stopPrank();
        }
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
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "this is a test hoodie",
            "hoodie image url",
            50000,
            SofamonWearables.SaleStates.PUBLIC
        );
        sofa.createWearable(
            SofamonWearables.CreateWearableParams({
                name: "test hoodie",
                category: "hoodie",
                description: "this is a test hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                curveAdjustmentFactor: 50000,
                signature: signature
            })
        );
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
