// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "./Ownable.sol";
import {LibString} from "./LibString.sol";

// TODO: Events, final pricing model

contract SofamonShares is Ownable {
    address public protocolFeeDestination;
    address public holderFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public holderFeePercent;
    string public baseMetadataURI;

    uint256 public thresholdSupply;

    event buyShare(
        address trader,
        address subject,
        uint256 shareId,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 holderEthAmount,
        uint256 supply
    );

    event sellShare(
        address trader,
        address subject,
        uint256 shareId,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 holderEthAmount,
        uint256 supply
    );

    // The supply of the current share for a specific holder
    // SharesSubject => (ID => (Holder => Balance))
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public sharesBalance;

    // The total supply of the current share
    // SharesSubject => (ID => Supply)
    mapping(address => mapping(uint256 => uint256)) public sharesSupply;

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
        string memory forwardSlash = "/";
        return
            LibString.concat(
                LibString.concat(baseMetadataURI_, forwardSlash),
                LibString.toString(shareId)
            );
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setHolderFeeDestination(
        address _holderFeeDestination
    ) public onlyOwner {
        holderFeeDestination = _holderFeeDestination;
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
        emit buyShare(
            msg.sender,
            sharesSubject,
            shareId,
            amount,
            price,
            protocolFee,
            subjectFee,
            holderFee,
            supply + amount
        );
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        (bool success3, ) = holderFeeDestination.call{value: holderFee}("");
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
        emit sellShare(
            msg.sender,
            sharesSubject,
            shareId,
            amount,
            price,
            protocolFee,
            subjectFee,
            holderFee,
            supply - amount
        );
        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee - holderFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        (bool success4, ) = holderFeeDestination.call{value: holderFee}("");
        require(
            success1 && success2 && success3 && success4,
            "Unable to send funds"
        );
    }
}
