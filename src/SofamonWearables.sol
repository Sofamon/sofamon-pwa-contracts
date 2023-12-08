// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "./Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SofamonWearables is Ownable {
    using ECDSA for bytes32;

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    address public createSigner;

    event Trade(
        address trader,
        bytes32 subject,
        bool isBuy,
        uint256 wearableAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 supply
    );

    event WearableCreated(
        address creator,
        string name,
        string template,
        string description,
        string imageURI
    );

    struct Wearable {
        address creator;
        string name;
        string template;
        string imageURI;
    }

    // WearablesSubject => Wearable
    mapping(bytes32 => Wearable) public wearables;

    // Holder => lastCreationTime
    mapping(address => uint256) public lastCreationTime;

    // wearablesSubject => (Holder => Balance)
    mapping(bytes32 => mapping(address => uint256)) public wearablesBalance;

    // wearablesSubject => Supply
    mapping(bytes32 => uint256) public wearablesSupply;

    constructor(address _signer) Ownable() {
        protocolFeePercent = 50000000000000000;
        subjectFeePercent = 50000000000000000;
        createSigner = _signer; // Set the signer's public key
    }

    function setProtocolFeeDestination(
        address _feeDestination
    ) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) external onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function setCreateSigner(address _signer) external onlyOwner {
        createSigner = _signer;
    }

    function createWearable(
        string memory name,
        string memory template,
        string memory description,
        string memory imageURI,
        bytes calldata signature
    ) public {
        // Validate signature
        bytes32 hashVal = keccak256(
            abi.encodePacked(msg.sender, name, template, description, imageURI)
        );
        require(_verifySignature(hashVal, signature), "INVALID_SIGNATURE");

        bytes32 wearablesSubject = keccak256(abi.encode(name, imageURI));
        lastCreationTime[msg.sender] = block.timestamp;
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply == 0, "WEARABLE_ALREADY_CREATED");
        wearables[wearablesSubject] = Wearable(
            msg.sender,
            name,
            template,
            imageURI
        );

        emit WearableCreated(msg.sender, name, template, description, imageURI);
        _buyWearables(wearablesSubject, supply, 1);
    }

    function _verifySignature(
        bytes32 hashVal,
        bytes calldata signature
    ) internal view returns (bool) {
        return
            hashVal.toEthSignedMessageHash().recover(signature) == createSigner;
    }

    function getPrice(
        uint256 supply,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 sum1 = supply == 0
            ? 0
            : ((supply - 1) * (supply) * (2 * (supply - 1) + 1)) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : ((supply - 1 + amount) *
                (supply + amount) *
                (2 * (supply - 1 + amount) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (summation * 1 ether) / 16000;
    }

    function getBuyPrice(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject], amount);
    }

    function getSellPrice(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject] - amount, amount);
    }

    function getBuyPriceAfterFee(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(wearablesSubject, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        return price + protocolFee + subjectFee;
    }

    function getSellPriceAfterFee(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(wearablesSubject, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        return price - protocolFee - subjectFee;
    }

    function getProtocolFee(uint256 price) internal view returns (uint256) {
        return (price * protocolFeePercent) / 1 ether;
    }

    function getSubjectFee(uint256 price) internal view returns (uint256) {
        return (price * subjectFeePercent) / 1 ether;
    }

    function buyWearables(
        bytes32 wearablesSubject,
        uint256 amount
    ) public payable {
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply > 0, "WEARABLE_NOT_CREATED");

        _buyWearables(wearablesSubject, supply, amount);
    }

    function _buyWearables(
        bytes32 wearablesSubject,
        uint256 supply,
        uint256 amount
    ) internal {
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        require(
            msg.value >= price + protocolFee + subjectFee,
            "INSUFFICIENT_PAYMENT"
        );
        wearablesBalance[wearablesSubject][msg.sender] =
            wearablesBalance[wearablesSubject][msg.sender] +
            amount;
        wearablesSupply[wearablesSubject] = supply + amount;

        address subjectFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(
            msg.sender,
            wearablesSubject,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply + amount
        );

        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = subjectFeeDestination.call{value: subjectFee}("");
        require(success1 && success2, "UNABLE_TO_SEND_FUNDS");
    }

    function sellWearables(
        bytes32 wearablesSubject,
        uint256 amount
    ) public payable {
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply > amount, "CANNOT_SELL_LAST_WEARABLE");

        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        require(
            wearablesBalance[wearablesSubject][msg.sender] >= amount,
            "INSUFFICIENT_HOLDINGS"
        );

        wearablesBalance[wearablesSubject][msg.sender] =
            wearablesBalance[wearablesSubject][msg.sender] -
            amount;
        wearablesSupply[wearablesSubject] = supply - amount;

        address subjectFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(
            msg.sender,
            wearablesSubject,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply - amount
        );

        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = subjectFeeDestination.call{value: subjectFee}("");

        require(success1 && success2 && success3, "UNABLE_TO_SEND_FUNDS");
    }
}
