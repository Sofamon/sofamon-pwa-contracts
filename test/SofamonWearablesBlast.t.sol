// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SofamonWearablesBlast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestBlast} from "../test/TestBlast.sol";
import {TestBlastPoints} from "../test/TestBlastPoints.sol";

contract SofamonWearablesBlastTest is Test {
    using ECDSA for bytes32;

    event BlastGovernorUpdated(address governor);

    event BlastPointsOperatorUpdated(address operator);

    event ProtocolFeeDestinationUpdated(address feeDestination);

    event ProtocolFeePercentUpdated(uint256 feePercent);

    event CreatorFeePercentUpdated(uint256 feePercent);

    event WearableSignerUpdated(address signer);

    event WearableOperatorUpdated(address operator);

    event WearableSaleStateUpdated(bytes32 wearablesSubject, SofamonWearablesBlast.SaleStates saleState);

    event NonceUpdated(address user, uint256 nonce);

    event WearableCreated(
        address creator,
        bytes32 subject,
        string name,
        string category,
        string imageURI,
        SofamonWearablesBlast.WearableFactors factors,
        SofamonWearablesBlast.SaleStates state
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

    ERC1967Proxy public proxy;
    SofamonWearablesBlast public proxySofa;

    uint256 internal signer1Privatekey = 0x1;
    uint256 internal signer2Privatekey = 0x2;

    address BLAST = 0x4300000000000000000000000000000000000002;
    address BLAST_POINTS = 0x2fc95838c71e76ec69ff817983BFf17c710F34E0;

    address owner = address(0x11);
    address operator = address(0x12);
    address operator2 = address(0x13);
    address governor = address(0x14);
    address protocolFeeDestination = address(0x22);
    address signer1 = vm.addr(signer1Privatekey);
    address signer2 = vm.addr(signer2Privatekey);
    address creator1 = address(0xa);
    address creator2 = address(0xb);
    address user1 = address(0xc);
    address user2 = address(0xd);

    function setUp() public {
        TestBlast testBlast = new TestBlast();
        TestBlastPoints testBlastPoints = new TestBlastPoints();
        vm.etch(BLAST, address(testBlast).code);
        vm.etch(BLAST_POINTS, address(testBlastPoints).code);

        vm.startPrank(owner);
        SofamonWearablesBlast sofa = new SofamonWearablesBlast();
        proxy = new ERC1967Proxy(address(sofa), "");
        proxySofa = SofamonWearablesBlast(address(proxy));
        proxySofa.initialize(owner, owner, operator, signer1);
    }

    function testSofamonWearablesBlastUpgradable() public {
        // deploy new sofa contract
        vm.startPrank(owner);
        SofamonWearablesBlast sofav2 = new SofamonWearablesBlast();
        SofamonWearablesBlast(address(proxy)).upgradeTo(address(sofav2));
        SofamonWearablesBlast proxySofav2 = SofamonWearablesBlast(address(proxy));
        vm.stopPrank();
        assertEq(proxySofav2.owner(), owner);
    }

    function testSetProtocolFeeAndCreatorFee() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeePercentUpdated(0.05 ether);
        proxySofa.setProtocolFeePercent(0.05 ether);
        vm.expectEmit(true, true, true, true);
        emit CreatorFeePercentUpdated(0.05 ether);
        proxySofa.setCreatorFeePercent(0.05 ether);
        assertEq(proxySofa.protocolFeePercent(), 0.05 ether);
        assertEq(proxySofa.creatorFeePercent(), 0.05 ether);
    }

    function testSetProtocolFeeDestination() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ProtocolFeeDestinationUpdated(protocolFeeDestination);
        proxySofa.setProtocolFeeDestination(protocolFeeDestination);
        assertEq(proxySofa.protocolFeeDestination(), protocolFeeDestination);
    }

    function testSetSigner() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WearableSignerUpdated(signer2);
        proxySofa.setWearableSigner(signer2);
        assertEq(proxySofa.wearableSigner(), signer2);
    }

    function testSetOperator() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit WearableOperatorUpdated(operator2);
        proxySofa.setWearableOperator(operator2);
        assertEq(proxySofa.wearableOperator(), operator2);
    }

    function testCreateWearable() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();
    }

    function testSetWearableSalesState() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );

        vm.expectEmit(true, true, true, true);
        emit WearableSaleStateUpdated(wearablesSubject, SofamonWearablesBlast.SaleStates.PRIVATE);
        proxySofa.setWearableSalesState(wearablesSubject, SofamonWearablesBlast.SaleStates.PRIVATE);
        vm.stopPrank();
    }

    function testBatchSetWearableSalesState() public {
        bytes32 wearablesSubject1 = keccak256(abi.encode("test hoodie", "hoodie image url"));
        bytes32 wearablesSubject2 = keccak256(abi.encode("test hoodie 2", "hoodie image url 2"));
        bytes32[] memory wearablesSubjects = new bytes32[](2);
        wearablesSubjects[0] = wearablesSubject1;
        wearablesSubjects[1] = wearablesSubject2;

        vm.startPrank(operator);
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie 2",
                category: "hoodie 2",
                imageURI: "hoodie image url 2",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );

        vm.expectEmit(true, true, true, true);
        emit WearableSaleStateUpdated(wearablesSubject1, SofamonWearablesBlast.SaleStates.PRIVATE);
        emit WearableSaleStateUpdated(wearablesSubject2, SofamonWearablesBlast.SaleStates.PRIVATE);
        proxySofa.batchSetWearableSalesState(wearablesSubjects, SofamonWearablesBlast.SaleStates.PRIVATE);
        vm.stopPrank();
    }

    function testBuyWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        uint256 buyPrice = proxySofa.getBuyPrice(wearablesSubject, 1 ether);
        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
        uint256 protocolFeePercent = proxySofa.protocolFeePercent();
        uint256 creatorFeePercent = proxySofa.creatorFeePercent();
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
        proxySofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);
    }

    function testBuyTotalSupplyExceeded() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 10, curveFactor: 200, initialPriceFactor: 200});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 10,
                curveFactor: 200,
                initialPriceFactor: 200
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        vm.expectRevert(bytes4(keccak256("TotalSupplyExceeded()")));
        proxySofa.getBuyPriceAfterFee(wearablesSubject, 10 ether);
    }

    function testPaymentsRefund() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
        // buy 1 full share of the wearable with excessive payment
        proxySofa.buyWearables{value: buyPriceAfterFee + 0.5 ether}(wearablesSubject, 1 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);
    }

    function testBuyPrivateWearablesFailed() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PRIVATE
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: false,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
        vm.expectRevert(bytes4(keccak256("InvalidSaleState()")));
        proxySofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether);
    }

    function testBuyPrivateWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));
        {
            vm.startPrank(operator);
            SofamonWearablesBlast.WearableFactors memory factors =
                SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
            vm.expectEmit(true, true, true, true);
            emit WearableCreated(
                creator1,
                wearablesSubject,
                "test hoodie",
                "hoodie",
                "hoodie image url",
                factors,
                SofamonWearablesBlast.SaleStates.PRIVATE
            );
            proxySofa.createWearable(
                SofamonWearablesBlast.CreateWearableParams({
                    creator: creator1,
                    name: "test hoodie",
                    category: "hoodie",
                    imageURI: "hoodie image url",
                    isPublic: false,
                    supplyFactor: 800,
                    curveFactor: 200,
                    initialPriceFactor: 245
                })
            );
            vm.stopPrank();
        }

        {
            uint256 nonce = proxySofa.nonces(user1);
            vm.startPrank(signer1);
            bytes32 digest2 = keccak256(abi.encodePacked(user1, "buy", wearablesSubject, uint256(1 ether), nonce))
                .toEthSignedMessageHash();
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signer1Privatekey, digest2);
            bytes memory signature2 = abi.encodePacked(r2, s2, v2);
            vm.stopPrank();

            vm.startPrank(user1);
            vm.deal(user1, 1 ether);
            assertEq(user1.balance, 1 ether);
            uint256 buyPrice = proxySofa.getBuyPrice(wearablesSubject, 1 ether);
            uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 1 ether);
            uint256 protocolFeePercent = proxySofa.protocolFeePercent();
            uint256 creatorFeePercent = proxySofa.creatorFeePercent();
            vm.expectEmit(true, true, true, true);
            emit NonceUpdated(user1, 1);
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
            proxySofa.buyPrivateWearables{value: buyPriceAfterFee}(wearablesSubject, 1 ether, signature2);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee);
        }
    }

    function testSellWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));
        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        // get price for 2 full share of the wearable
        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 2 ether);
        proxySofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 2 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);
        assertEq(proxySofa.wearablesBalance(wearablesSubject, user1), 2 ether);

        uint256 sellPrice = proxySofa.getSellPrice(wearablesSubject, 1 ether);
        uint256 sellPriceAfterFee = proxySofa.getSellPriceAfterFee(wearablesSubject, 1 ether);
        uint256 protocolFeePercent = proxySofa.protocolFeePercent();
        uint256 creatorFeePercent = proxySofa.creatorFeePercent();
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
        proxySofa.sellWearables(wearablesSubject, 1 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee + sellPriceAfterFee);
        assertEq(proxySofa.wearablesBalance(wearablesSubject, user1), 1 ether);
    }

    function testSellPrivateWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));
        {
            vm.startPrank(operator);
            SofamonWearablesBlast.WearableFactors memory factors =
                SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
            vm.expectEmit(true, true, true, true);
            emit WearableCreated(
                creator1,
                wearablesSubject,
                "test hoodie",
                "hoodie",
                "hoodie image url",
                factors,
                SofamonWearablesBlast.SaleStates.PRIVATE
            );
            proxySofa.createWearable(
                SofamonWearablesBlast.CreateWearableParams({
                    creator: creator1,
                    name: "test hoodie",
                    category: "hoodie",
                    imageURI: "hoodie image url",
                    isPublic: false,
                    supplyFactor: 800,
                    curveFactor: 200,
                    initialPriceFactor: 245
                })
            );
            vm.stopPrank();
        }

        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 2 ether);

        {
            uint256 nonce1 = proxySofa.nonces(user1);
            vm.startPrank(signer1);
            bytes32 digest2 = keccak256(abi.encodePacked(user1, "buy", wearablesSubject, uint256(2 ether), nonce1))
                .toEthSignedMessageHash();
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signer1Privatekey, digest2);
            bytes memory signature2 = abi.encodePacked(r2, s2, v2);
            vm.stopPrank();

            vm.startPrank(user1);
            vm.deal(user1, 1 ether);
            assertEq(user1.balance, 1 ether);
            // get price for 2 full share of the wearable
            proxySofa.buyPrivateWearables{value: buyPriceAfterFee}(wearablesSubject, 2 ether, signature2);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee);
            assertEq(proxySofa.wearablesBalance(wearablesSubject, user1), 2 ether);
            vm.stopPrank();
        }

        {
            uint256 nonce2 = proxySofa.nonces(user1);
            vm.startPrank(signer1);
            bytes32 digest3 = keccak256(abi.encodePacked(user1, "sell", wearablesSubject, uint256(1 ether), nonce2))
                .toEthSignedMessageHash();
            (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(signer1Privatekey, digest3);
            bytes memory signature3 = abi.encodePacked(r3, s3, v3);
            vm.stopPrank();

            vm.startPrank(user1);
            uint256 sellPrice = proxySofa.getSellPrice(wearablesSubject, 1 ether);
            uint256 sellPriceAfterFee = proxySofa.getSellPriceAfterFee(wearablesSubject, 1 ether);
            uint256 protocolFeePercent = proxySofa.protocolFeePercent();
            uint256 creatorFeePercent = proxySofa.creatorFeePercent();
            vm.expectEmit(true, true, true, true);
            emit NonceUpdated(user1, 2);
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
            proxySofa.sellPrivateWearables(wearablesSubject, 1 ether, signature3);
            assertEq(user1.balance, 1 ether - buyPriceAfterFee + sellPriceAfterFee);
            assertEq(proxySofa.wearablesBalance(wearablesSubject, user1), 1 ether);
            vm.stopPrank();
        }
    }

    function testSellAllWearables() public {
        // Setup wearable
        // ------------------------------------------------------------
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();
        // ------------------------------------------------------------

        vm.startPrank(creator1);
        vm.deal(creator1, 1_000_000 ether);

        uint256 total = 0;
        // buy 10 batches of wearables
        for (uint256 i; i < 10; i++) {
            uint256 amount = 1e18;
            total += amount;
            uint256 buyPrice = proxySofa.getBuyPriceAfterFee(wearablesSubject, amount);
            proxySofa.buyWearables{value: buyPrice}(wearablesSubject, amount);
        }

        console.log("sellPrice                ", proxySofa.getSellPrice(wearablesSubject, total));
        console.log("SofamonWearablesBlast balance:", address(proxySofa).balance);

        // Sell all wearables
        proxySofa.sellWearables(wearablesSubject, total);

        console.log(creator1.balance);
    }

    function testTransferWearables() public {
        bytes32 wearablesSubject = keccak256(abi.encode("test hoodie", "hoodie image url"));

        vm.startPrank(operator);
        SofamonWearablesBlast.WearableFactors memory factors =
            SofamonWearablesBlast.WearableFactors({supplyFactor: 800, curveFactor: 200, initialPriceFactor: 245});
        vm.expectEmit(true, true, true, true);
        emit WearableCreated(
            creator1,
            wearablesSubject,
            "test hoodie",
            "hoodie",
            "hoodie image url",
            factors,
            SofamonWearablesBlast.SaleStates.PUBLIC
        );
        proxySofa.createWearable(
            SofamonWearablesBlast.CreateWearableParams({
                creator: creator1,
                name: "test hoodie",
                category: "hoodie",
                imageURI: "hoodie image url",
                isPublic: true,
                supplyFactor: 800,
                curveFactor: 200,
                initialPriceFactor: 245
            })
        );
        vm.stopPrank();

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        assertEq(user1.balance, 1 ether);
        // get price for 3 full share of the wearable
        uint256 buyPriceAfterFee = proxySofa.getBuyPriceAfterFee(wearablesSubject, 3 ether);
        proxySofa.buyWearables{value: buyPriceAfterFee}(wearablesSubject, 3 ether);
        assertEq(user1.balance, 1 ether - buyPriceAfterFee);

        // transfer 1 full share of the wearable to user2
        vm.expectEmit(true, true, true, true);
        emit WearableTransferred(user1, user2, wearablesSubject, 1 ether);
        proxySofa.transferWearables(wearablesSubject, user1, user2, 1 ether);
        assertEq(proxySofa.wearablesBalance(wearablesSubject, user1), 2 ether);
        assertEq(proxySofa.wearablesBalance(wearablesSubject, user2), 1 ether);
    }
}
