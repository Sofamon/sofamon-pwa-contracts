// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "./Ownable.sol";

contract SofamonShares is Ownable {
    address public protocolFeeDestination;
    address public holderFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public holderFeePercent;

    event Trade(
        address trader,
        bytes32 subject,
        bool isBuy,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 holderEthAmount,
        uint256 supply
    );

    event WearableCreated(
        address creator,
        string name,
        string category,
        string description,
        string imageURI
    );

    struct Wearable {
        address creator;
        string name;
        string category;
        string imageURI;
    }

    // SharesSubject => Wearable
    mapping(bytes32 => Wearable) public wearables;

    // Holder => lastCreationTime
    mapping(address => uint256) public lastCreationTime;

    // The cooldown period between creations
    uint256 public cooldown = 1 days;

    // SharesSubject => (Holder => Balance)
    mapping(bytes32 => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(bytes32 => uint256) public sharesSupply;

    constructor() Ownable() {
        protocolFeePercent = 50000000000000000;
        subjectFeePercent = 50000000000000000;
        holderFeePercent = 50000000000000000;
    }

    function setProtocolFeeDestination(
        address _feeDestination
    ) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setHolderFeeDestination(address _feeDestination) public onlyOwner {
        holderFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function setHolderFeePercent(uint256 _feePercent) public onlyOwner {
        holderFeePercent = _feePercent;
    }

    function createWearable(
        string memory name,
        string memory category,
        string memory description,
        string memory imageURI
    ) public {
        require(
            block.timestamp >= lastCreationTime[msg.sender] + cooldown,
            "WAIT_FOR_COOLDOWN"
        );
        bytes32 sharesSubject = keccak256(abi.encode(name, imageURI));
        lastCreationTime[msg.sender] = block.timestamp;
        uint256 supply = sharesSupply[sharesSubject];
        require(supply == 0, "ITEM_ALREADY_CREATED");
        wearables[sharesSubject] = Wearable(
            msg.sender,
            name,
            category,
            imageURI
        );

        emit WearableCreated(msg.sender, name, category, description, imageURI);
        _buyShares(sharesSubject, supply, 1);
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
        bytes32 sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject], amount);
    }

    function getSellPrice(
        bytes32 sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject] - amount, amount);
    }

    function getBuyPriceAfterFee(
        bytes32 sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        uint256 holderFee = getHolderFee(price);
        return price + protocolFee + subjectFee + holderFee;
    }

    function getSellPriceAfterFee(
        bytes32 sharesSubject,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        uint256 holderFee = getHolderFee(price);
        return price - protocolFee - subjectFee - holderFee;
    }

    function getProtocolFee(uint256 price) internal view returns (uint256) {
        return (price * protocolFeePercent) / 1 ether;
    }

    function getSubjectFee(uint256 price) internal view returns (uint256) {
        return (price * subjectFeePercent) / 1 ether;
    }

    function getHolderFee(uint256 price) internal view returns (uint256) {
        return (price * holderFeePercent) / 1 ether;
    }

    function buyShares(bytes32 sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > 0, "ITEM_NOT_CREATED");

        _buyShares(sharesSubject, supply, amount);
    }

    function _buyShares(
        bytes32 sharesSubject,
        uint256 supply,
        uint256 amount
    ) internal {
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        uint256 holderFee = getHolderFee(price);
        require(
            msg.value >= price + protocolFee + subjectFee + holderFee,
            "INSUFFICIENT_PAYMENT"
        );
        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] +
            amount;
        sharesSupply[sharesSubject] = supply + amount;

        address subjectFeeDestination = wearables[sharesSubject].creator;

        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            holderFee,
            supply + amount
        );

        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = subjectFeeDestination.call{value: subjectFee}("");
        (bool success3, ) = holderFeeDestination.call{value: holderFee}("");
        require(success1 && success2 && success3, "UNABLE_TO_SEND_FUNDS");
    }

    function sellShares(bytes32 sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "CANNOT_SELL_LAST_ITEM");

        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = getProtocolFee(price);
        uint256 subjectFee = getSubjectFee(price);
        uint256 holderFee = getHolderFee(price);
        require(
            sharesBalance[sharesSubject][msg.sender] >= amount,
            "INSUFFICIENT_HOLDINGS"
        );

        sharesBalance[sharesSubject][msg.sender] =
            sharesBalance[sharesSubject][msg.sender] -
            amount;
        sharesSupply[sharesSubject] = supply - amount;

        address subjectFeeDestination = wearables[sharesSubject].creator;

        emit Trade(
            msg.sender,
            sharesSubject,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            0,
            supply - amount
        );

        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee - holderFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = subjectFeeDestination.call{value: subjectFee}("");
        (bool success4, ) = holderFeeDestination.call{value: holderFee}("");

        require(
            success1 && success2 && success3 && success4,
            "UNABLE_TO_SEND_FUNDS"
        );
    }
}
