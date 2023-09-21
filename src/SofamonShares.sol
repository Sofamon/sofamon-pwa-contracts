// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "./Ownable.sol";
import {LibString} from "./LibString.sol";

// TODO: Events, final pricing model

contract SofamonShares is Ownable {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public holderFeePercent;
    string public baseMetadataURI;

    uint256 public thresholdSupply;

    event Trade(
        address trader,
        address subject,
        bool isBuy,
        uint256 shareId,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 holderEthAmount,
        uint256 subjectEthAmount,
        uint256 supply
    );

    struct Holder {
        address holderAddress;
        uint256 shareBalance;
    }

    // The supply of the current share for a specific holder
    // SharesSubject => (ID => (Holder => Balance))
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public sharesBalance;

    // The total supply of the current share
    // SharesSubject => (ID => Supply)
    mapping(address => mapping(uint256 => uint256)) public sharesSupply;

    // Mapping to store holders for each share subject
    // SharesSubject => (ID => Holder)
    mapping(address => mapping(uint256 => Holder[])) public shareHolders;

    function setURI(string memory _baseMetadataURI) public onlyOwner {
        baseMetadataURI = _baseMetadataURI;
    }

    function shareURI(
        address sharesSubject,
        uint256 shareId
    ) public view returns (string memory) {
        string memory baseMetadataURI_ = LibString.concat(
            baseMetadataURI,
            LibString.toString(sharesSubject)
        );
        return LibString.concat(baseMetadataURI_, LibString.toString(shareId));
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
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

    function setThresholdSupply(uint256 _threshold) public onlyOwner {
        thresholdSupply = _threshold;
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
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject][shareId], amount);
    }

    function getSellPrice(
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(sharesSupply[sharesSubject][shareId] - amount, amount);
    }

    function getBuyPriceAfterFee(
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, shareId, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        uint256 holderFee = (price * holderFeePercent) / 1 ether;
        return price + protocolFee + subjectFee + holderFee;
    }

    function getSellPriceAfterFee(
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, shareId, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        uint256 holderFee = (price * holderFeePercent) / 1 ether;
        return price - protocolFee - subjectFee - holderFee;
    }

    // Function to distribute the holder's fee among all holders
    function distributeHolderFee(
        address sharesSubject,
        uint256 shareId,
        uint256 holderFee
    ) internal {
        Holder[] storage holders = shareHolders[sharesSubject][shareId];
        uint256 totalShares = sharesSupply[sharesSubject][shareId];

        // Distribute the holder's fee proportionally to each holder
        for (uint256 i = 0; i < holders.length; i++) {
            uint256 feeShare = (holders[i].shareBalance * holderFee) /
                totalShares;
            (bool success, ) = holders[i].holderAddress.call{value: feeShare}(
                ""
            );
            require(success, "Failed to distribute holder's fee");
        }
    }

    function buyShares(
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public payable {
        uint256 supply = sharesSupply[sharesSubject][shareId];
        uint256 count = sharesBalance[sharesSubject][shareId][msg.sender];
        require(
            supply > 0 || sharesSubject == msg.sender,
            "Only the shares' subject can buy the first share"
        );

        // Check if the total supply is below the threshold, and if so, limit the user to buying 1 share
        if (supply < thresholdSupply) {
            require(
                amount == 1 && count == 0,
                "You can only buy 1 share when the supply is below the threshold, and you don't already own shares"
            );
        }

        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        uint256 holderFee = (price * holderFeePercent) / 1 ether;
        require(
            msg.value >= price + protocolFee + subjectFee,
            "Insufficient payment"
        );
        sharesBalance[sharesSubject][shareId][msg.sender] =
            sharesBalance[sharesSubject][shareId][msg.sender] +
            amount;
        sharesSupply[sharesSubject][shareId] = supply + amount;
        emit Trade(
            msg.sender,
            sharesSubject,
            true,
            shareId,
            amount,
            price,
            protocolFee,
            holderFee,
            subjectFee,
            supply + amount
        );
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        // Distribute holder's fee among all holders
        distributeHolderFee(sharesSubject, shareId, holderFee);
        bool success3 = true;
        require(success1 && success2 && success3, "Unable to send funds");
    }

    function sellShares(
        address sharesSubject,
        uint256 shareId,
        uint256 amount
    ) public payable {
        uint256 supply = sharesSupply[sharesSubject][shareId];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        uint256 holderFee = (price * holderFeePercent) / 1 ether;
        require(
            sharesBalance[sharesSubject][shareId][msg.sender] >= amount,
            "Insufficient shares"
        );
        sharesBalance[sharesSubject][shareId][msg.sender] =
            sharesBalance[sharesSubject][shareId][msg.sender] -
            amount;
        sharesSupply[sharesSubject][shareId] = supply - amount;
        emit Trade(
            msg.sender,
            sharesSubject,
            false,
            shareId,
            amount,
            price,
            protocolFee,
            holderFee,
            subjectFee,
            supply - amount
        );
        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        // Distribute holder's fee among all holders
        distributeHolderFee(sharesSubject, shareId, holderFee);
        bool success4;
        require(
            success1 && success2 && success3 && success4,
            "Unable to send funds"
        );
    }
}
