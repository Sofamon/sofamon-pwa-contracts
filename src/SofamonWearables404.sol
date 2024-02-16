// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Errors
error InvalidSignature();
error InsufficientBaseUnit();
error WearableAlreadyCreated();
error WearableNotCreated();
error InsufficientPayment();
error SendFundsFailed();
error LastWearableCannotBeSold();
error InsufficientHoldings();
error TransferToZeroAddress();
error IncorrectSender();

/**
 * @title SofamonWearables
 * @author lixingyu.eth <@0xlxy>
 */
contract SofamonWearables is Ownable2Step {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // 3% creator fee
    uint256 public constant CREATOR_FEE_PERCENT = 0.03 ether;

    // 3% protocol fee
    uint256 public constant PROTOCOL_FEE_PERCENT = 0.03 ether;

    // Base unit of a wearable. 1000 fractional shares = 1 full wearable
    uint256 public constant BASE_WEARABLE_UNIT = 0.001 ether;

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

    event WearableCreated(address creator, string name, string template, string description, string imageURI);

    event WearableTransferred(address from, address to, bytes32 subject, uint256 amount);

    struct Wearable {
        address creator;
        string name;
        string template;
        string description;
        string imageURI;
    }

    // wearablesSubject => Wearable
    mapping(bytes32 => Wearable) public wearables;

    // wearablesSubject => (Holder => Balance)
    mapping(bytes32 => mapping(address => uint256)) public wearablesBalance;

    // wearablesSubject => Supply
    mapping(bytes32 => uint256) public wearablesSupply;

    constructor(address _owner, address _signer) Ownable(_owner) {
        protocolFeePercent = PROTOCOL_FEE_PERCENT;
        subjectFeePercent = CREATOR_FEE_PERCENT;
        createSigner = _signer;
    }

    // =========================================================================
    //                          Protocol Settings
    // =========================================================================

    /// @dev Sets the protocol fee destination.
    function setProtocolFeeDestination(address _feeDestination) external onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    /// @dev Sets the protocol fee percentage.
    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        protocolFeePercent = _feePercent;
    }

    /// @dev Sets the subject fee percentage.
    function setSubjectFeePercent(uint256 _feePercent) external onlyOwner {
        subjectFeePercent = _feePercent;
    }

    /// @dev Sets the address that signs messages used for creating wearables.
    function setCreateSigner(address _signer) external onlyOwner {
        createSigner = _signer;
    }

    // =========================================================================
    //                          Create Wearable Logic
    // =========================================================================

    /// @dev Creates a sofamon wearable. invite-code needed.
    /// Emits a {WearableCreated} event.
    function createWearable(
        string calldata name,
        string calldata template,
        string calldata description,
        string calldata imageURI,
        bytes calldata signature
    ) external {
        // Validate signature
        bytes32 hashVal = keccak256(abi.encodePacked(msg.sender, name, template, description, imageURI));
        bytes32 signedHash = hashVal.toEthSignedMessageHash();
        if (signedHash.recover(signature) != createSigner) {
            revert InvalidSignature();
        }

        // Generate wearable subject
        bytes32 wearablesSubject = keccak256(abi.encode(name, imageURI));

        // Check if wearable already exists
        uint256 supply = wearablesSupply[wearablesSubject];
        if (supply != 0) revert WearableAlreadyCreated();

        // Update wearables mapping
        wearables[wearablesSubject] = Wearable(msg.sender, name, template, description, imageURI);

        emit WearableCreated(msg.sender, name, template, description, imageURI);
    }

    // =========================================================================
    //                          Trade Wearable Logic
    // =========================================================================
    /// @dev Returns the curve of `x`
    function _curve(uint256 x) private pure returns (uint256) {
        return x * x * x;
    }

    /// @dev Returns the price based on `supply` and `amount`
    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        return (_curve(supply + amount) - _curve(supply)) / 1 ether / 1 ether / 48_000;
    }

    /// @dev Returns the buy price of `amount` of `wearablesSubject`.
    function getBuyPrice(bytes32 wearablesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject], amount);
    }

    /// @dev Returns the sell price of `amount` of `wearablesSubject`.
    function getSellPrice(bytes32 wearablesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(wearablesSupply[wearablesSubject] - amount, amount);
    }

    /// @dev Returns the buy price of `amount` of `wearablesSubject` after fee.
    function getBuyPriceAfterFee(bytes32 wearablesSubject, uint256 amount) external view returns (uint256) {
        // Get buy price before fee
        uint256 price = getBuyPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Get final buy price
        return price + protocolFee + subjectFee;
    }

    /// @dev Returns the sell price of `amount` of `wearablesSubject` after fee.
    function getSellPriceAfterFee(bytes32 wearablesSubject, uint256 amount) external view returns (uint256) {
        // Get sell price before fee
        uint256 price = getSellPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Get final sell price
        return price - protocolFee - subjectFee;
    }

    /// @dev Returns the protocol fee.
    function _getProtocolFee(uint256 price) internal view returns (uint256) {
        return (price * protocolFeePercent) / 1 ether;
    }

    /// @dev Returns the subject fee.
    function _getSubjectFee(uint256 price) internal view returns (uint256) {
        return (price * subjectFeePercent) / 1 ether;
    }

    /// @dev Buys `amount` of `wearablesSubject`.
    /// Emits a {Trade} event.
    function buyWearables(bytes32 wearablesSubject, uint256 amount) external payable {
        // Check if amount is greater than base unit
        if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

        // Check if wearable exists
        uint256 supply = wearablesSupply[wearablesSubject];
        if (supply == 0) revert WearableNotCreated();

        // Get buy price before fee
        uint256 price = getPrice(supply, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Check if user has enough funds
        if (msg.value < price + protocolFee + subjectFee) {
            revert InsufficientPayment();
        }

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] = wearablesBalance[wearablesSubject][msg.sender] + amount;
        wearablesSupply[wearablesSubject] = supply + amount;

        // Get subject fee destination
        address subjectFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(msg.sender, wearablesSubject, true, amount, price, protocolFee, subjectFee, supply + amount);

        // Send protocol fee to protocol fee destination
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");

        //Send subject fee to subject fee destination
        (bool success2,) = subjectFeeDestination.call{value: subjectFee}("");

        // Check if all funds were sent successfully
        if (!(success1 && success2)) revert SendFundsFailed();
    }

    /// @dev Sells `amount` of `wearablesSubject`.
    /// Emits a {Trade} event.
    function sellWearables(bytes32 wearablesSubject, uint256 amount) external payable {
        // Check if amount is greater than base unit
        if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

        // Check if wearable exists
        uint256 supply = wearablesSupply[wearablesSubject];
        if (supply <= amount) revert LastWearableCannotBeSold();

        // Get sell price before fee
        uint256 price = getPrice(supply - amount, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get subject fee
        uint256 subjectFee = _getSubjectFee(price);

        // Check if user has enough amount for sale
        if (wearablesBalance[wearablesSubject][msg.sender] < amount) {
            revert InsufficientHoldings();
        }

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] = wearablesBalance[wearablesSubject][msg.sender] - amount;
        wearablesSupply[wearablesSubject] = supply - amount;

        // Get subject fee destination
        address subjectFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(msg.sender, wearablesSubject, false, amount, price, protocolFee, subjectFee, supply - amount);

        // Send sell funds to seller
        (bool success1,) = msg.sender.call{value: price - protocolFee - subjectFee}("");

        // Send protocol fee to protocol fee destination
        (bool success2,) = protocolFeeDestination.call{value: protocolFee}("");

        // Send subject fee to subject fee destination
        (bool success3,) = subjectFeeDestination.call{value: subjectFee}("");

        // Check if all funds were sent successfully
        if (!(success1 && success2 && success3)) revert SendFundsFailed();
    }

    /// @dev Transfers `amount` of `wearablesSubject` from `from` to `to`.
    /// Emits a {WearableTransferred} event.
    function transferWearables(bytes32 wearablesSubject, address from, address to, uint256 amount) external {
        // Check if to address is non-zero
        if (to == address(0)) revert TransferToZeroAddress();

        // Check if amount is greater than base unit
        if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

        // Check if message sender is the from address
        if (_msgSender() != from) revert IncorrectSender();

        // Check if user has enough wearables for transfer
        if (wearablesBalance[wearablesSubject][from] < amount) {
            revert InsufficientHoldings();
        }

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][from] = wearablesBalance[wearablesSubject][from] - amount;
        wearablesBalance[wearablesSubject][to] = wearablesBalance[wearablesSubject][to] + amount;

        emit WearableTransferred(from, to, wearablesSubject, amount);
    }
}
