// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SofamonWearables
 * @author lixingyu.eth <@0xlxy>
 */
contract SofamonWearables is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Address of the protocol fee destination
    address public protocolFeeDestination;

    // Percentage of the protocol fee
    uint256 public protocolFeePercent;

    // Percentage of the subject fee
    uint256 public subjectFeePercent;

    // Address that signs messages used for creating wearables
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

    // wearablesSubject => Wearable
    mapping(bytes32 => Wearable) public wearables;

    // wearablesSubject => (Holder => Balance)
    mapping(bytes32 => mapping(address => uint256)) public wearablesBalance;

    // wearablesSubject => Supply
    mapping(bytes32 => uint256) public wearablesSupply;

    constructor(address _owner, address _signer) Ownable(_owner) {
        // 5% protocol fee
        protocolFeePercent = 50000000000000000;

        // 5% subject fee
        subjectFeePercent = 50000000000000000;

        // Set create signer
        createSigner = _signer;
    }

    // =========================================================================
    //                          Protocol Settings
    // =========================================================================

    /**
     * Owner-only function to set the protocol fee destination address
     * @param _feeDestination Address that will receive the protocol fee
     */
    function setProtocolFeeDestination(
        address _feeDestination
    ) external onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    /**
     * Owner-only function to set the protocol fee percentage
     * @param _feePercent Percentage of the protocol fee
     */
    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        protocolFeePercent = _feePercent;
    }

    /**
     * Owner-only function to set the subject fee percentage
     * @param _feePercent Percentage of the subject fee
     */
    function setSubjectFeePercent(uint256 _feePercent) external onlyOwner {
        subjectFeePercent = _feePercent;
    }

    /**
     * Owner-only function to set the create wearable signer
     * @param _signer Address that signs messages used for creating wearables
     */
    function setCreateSigner(address _signer) external onlyOwner {
        createSigner = _signer;
    }

    // =========================================================================
    //                          Create Wearable Logic
    // =========================================================================

    /**
     * Function to create a sofamon wearable. invite-code needed.
     * @param name Name of the wearable
     * @param template Template of the wearable
     * @param description Description of the wearable
     * @param imageURI Image URI of the wearable
     * @param signature Signature generated from the backend
     */
    function createWearable(
        string memory name,
        string memory template,
        string memory description,
        string memory imageURI,
        bytes calldata signature
    ) external {
        // Validate signature
        bytes32 hashVal = keccak256(
            abi.encodePacked(msg.sender, name, template, description, imageURI)
        );
        bytes32 signedHash = hashVal.toEthSignedMessageHash();
        require(signedHash.recover(signature) == createSigner, "INVALID_SIGNATURE");

        // Generate wearable subject
        bytes32 wearablesSubject = keccak256(abi.encode(name, imageURI));

        // Check if wearable already exists
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply == 0, "WEARABLE_ALREADY_CREATED");

        // Update wearables mapping
        wearables[wearablesSubject] = Wearable(
            msg.sender,
            name,
            template,
            imageURI
        );

        emit WearableCreated(msg.sender, name, template, description, imageURI);

        // Creator gets the first wearable
        _buyWearables(wearablesSubject, supply, 1);
    }

    // =========================================================================
    //                          Trade Wearable Logic
    // =========================================================================

    /**
     * Pure function to get the price based on the supply and amount
     * @param supply Current supply of the wearable
     * @param amount Amount of wearables to buy or sell
     */
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

    /**
     * View function to get the buy price of a wearable
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to buy
     */
    function getBuyPrice(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject], amount);
    }

    /**
     * View function to get the sell price of a wearable
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to sell
     */
    function getSellPrice(
        bytes32 wearablesSubject,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject] - amount, amount);
    }

    /**
     * View function to get the buy price of a wearable after fee
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to buy
     */
    function getBuyPriceAfterFee(
        bytes32 wearablesSubject,
        uint256 amount
    ) external view returns (uint256) {
        // Get buy price before fee
        uint256 price = getBuyPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Get final buy price
        return price + protocolFee + subjectFee;
    }

    /**
     * View function to get the sell price of a wearable after fee
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to sell
     */
    function getSellPriceAfterFee(
        bytes32 wearablesSubject,
        uint256 amount
    ) external view returns (uint256) {
        // Get sell price before fee
        uint256 price = getSellPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Get final sell price
        return price - protocolFee - subjectFee;
    }

    /**
     * Internal function to get the protocol fee
     * @param price Price of the wearable
     */
    function _getProtocolFee(uint256 price) internal view returns (uint256) {
        return (price * protocolFeePercent) / 1 ether;
    }

    /**
     * Internal function to get the subject fee
     * @param price Price of the wearable
     */
    function _getSubjectFee(uint256 price) internal view returns (uint256) {
        return (price * subjectFeePercent) / 1 ether;
    }

    /**
     * Function to buy wearables
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to buy
     */
    function buyWearables(
        bytes32 wearablesSubject,
        uint256 amount
    ) external payable {
        // Check if wearable exists
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply > 0, "WEARABLE_NOT_CREATED");

        // Buy wearables
        _buyWearables(wearablesSubject, supply, amount);
    }

    /**
     * Internal function to buy wearables. Used when creating and buying wearable
     * @param wearablesSubject Subject of the wearable
     * @param supply Current supply of the wearable
     * @param amount Amount of wearables to buy
     */
    function _buyWearables(
        bytes32 wearablesSubject,
        uint256 supply,
        uint256 amount
    ) internal {
        // Get buy price before fee
        uint256 price = getPrice(supply, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Check if user has enough funds
        require(
            msg.value >= price + protocolFee + subjectFee,
            "INSUFFICIENT_PAYMENT"
        );

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] =
            wearablesBalance[wearablesSubject][msg.sender] +
            amount;
        wearablesSupply[wearablesSubject] = supply + amount;

        // Get subject fee destination
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

        // Send protocol fee to protocol fee destination
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");

        //Send subject fee to subject fee destination
        (bool success2, ) = subjectFeeDestination.call{value: subjectFee}("");

        // Check if all funds were sent successfully
        require(success1 && success2, "UNABLE_TO_SEND_FUNDS");
    }

    /**
     * Function to sell wearables
     * @param wearablesSubject Subject of the wearable
     * @param amount Amount of wearables to sell
     */
    function sellWearables(
        bytes32 wearablesSubject,
        uint256 amount
    ) external payable {
        // Check if wearable exists
        uint256 supply = wearablesSupply[wearablesSubject];
        require(supply > amount, "CANNOT_SELL_LAST_WEARABLE");

        // Get sell price before fee
        uint256 price = getPrice(supply - amount, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Check if user has enough wearables for sale
        require(
            wearablesBalance[wearablesSubject][msg.sender] >= amount,
            "INSUFFICIENT_HOLDINGS"
        );

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] =
            wearablesBalance[wearablesSubject][msg.sender] -
            amount;
        wearablesSupply[wearablesSubject] = supply - amount;

        // Get subject fee destination
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

        // Send sell funds to seller
        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee
        }("");

        // Send protocol fee to protocol fee destination
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");

        // Send subject fee to subject fee destination
        (bool success3, ) = subjectFeeDestination.call{value: subjectFee}("");

        // Check if all funds were sent successfully
        require(success1 && success2 && success3, "UNABLE_TO_SEND_FUNDS");
    }
}
