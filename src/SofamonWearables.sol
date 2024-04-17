// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

// Errors
error InvalidFeePercent();
error InvalidSignature();
error InvalidOperator();
error InsufficientBaseUnit();
error AmountNotMultipleOfBaseUnit();
error InvalidTotalSupply();
error InvalidCurveFactor();
error InvalidInitialPriceFactor();
error WearableAlreadyCreated();
error WearableNotCreated();
error InvalidSaleState();
error TotalSupplyExceeded();
error InsufficientPayment();
error ExcessivePayment();
error SendFundsFailed();
error RefundFailed();
error InsufficientHoldings();
error TransferToZeroAddress();
error IncorrectSender();

/**
 * @title SofamonWearables
 * @author lixingyu.eth <@0xlxy>
 */
contract SofamonWearables is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;

    enum SaleStates {
        PRIVATE,
        PUBLIC
    }

    // 3% creator fee
    uint256 private constant CREATOR_FEE_PERCENT = 0.03 ether;

    // 3% protocol fee
    uint256 private constant PROTOCOL_FEE_PERCENT = 0.03 ether;

    // Base unit of a wearable. 1000 fractional shares = 1 full wearable
    uint256 private constant BASE_WEARABLE_UNIT = 0.001 ether;

    // Address of the protocol fee destination
    address public protocolFeeDestination;

    // Percentage of the protocol fee
    uint256 public protocolFeePercent;

    // Percentage of the creator fee
    uint256 public creatorFeePercent;

    // Address that signs messages used for creating wearables and private sales
    address public wearableSigner;

    // Address that signs messages used for creating wearables
    address public wearableOperator;

    event ProtocolFeeDestinationUpdated(address feeDestination);

    event ProtocolFeePercentUpdated(uint256 feePercent);

    event CreatorFeePercentUpdated(uint256 feePercent);

    event WearableSignerUpdated(address signer);

    event WearableOperatorUpdated(address operator);

    event WearableSaleStateUpdated(bytes32 wearablesSubject, SaleStates saleState);

    event WearableCreated(
        address creator,
        bytes32 subject,
        string name,
        string category,
        string imageURI,
        WearableFactors factors,
        SaleStates state
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

    event NonceUpdated(address user, uint256 nonce);

    event WearableTransferred(address from, address to, bytes32 subject, uint256 amount);

    struct WearableFactors {
        uint256 supplyFactor;
        uint256 curveFactor;
        uint256 initialPriceFactor;
    }

    struct CreateWearableParams {
        address creator;
        string name;
        string category;
        string imageURI;
        bool isPublic;
        uint256 supplyFactor;
        uint256 curveFactor;
        uint256 initialPriceFactor;
    }

    struct Wearable {
        address creator;
        string name;
        string category;
        string imageURI;
        WearableFactors factors;
        SaleStates state;
    }

    // wearablesSubject => Wearable
    mapping(bytes32 => Wearable) public wearables;

    // wearablesSubject => (holder => balance)
    mapping(bytes32 => mapping(address => uint256)) public wearablesBalance;

    // wearablesSubject => supply
    mapping(bytes32 => uint256) public wearablesSupply;

    // userAddress => nonce
    mapping(address => uint256) public nonces;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _wearableOperator, address _signer) public initializer {
        // Configure protocol settings
        protocolFeePercent = PROTOCOL_FEE_PERCENT;
        creatorFeePercent = CREATOR_FEE_PERCENT;
        wearableOperator = _wearableOperator;
        wearableSigner = _signer;

        __Ownable2Step_init();
        __UUPSUpgradeable_init();
    }

    // =========================================================================
    //                          Upgrade Implementation
    // =========================================================================
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // =========================================================================
    //                          Protocol Settings
    // =========================================================================

    /// @dev Sets the protocol fee destination.
    /// Emits a {ProtocolFeeDestinationUpdated} event.
    function setProtocolFeeDestination(address _feeDestination) external onlyOwner {
        protocolFeeDestination = _feeDestination;
        emit ProtocolFeeDestinationUpdated(_feeDestination);
    }

    /// @dev Sets the protocol fee percentage.
    /// Emits a {ProtocolFeePercentUpdated} event.
    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        if (_feePercent + creatorFeePercent > 0.2 ether) revert InvalidFeePercent();

        protocolFeePercent = _feePercent;
        emit ProtocolFeePercentUpdated(_feePercent);
    }

    /// @dev Sets the creator fee percentage.
    /// Emits a {CreatorFeePercentUpdated} event.
    function setCreatorFeePercent(uint256 _feePercent) external onlyOwner {
        if (_feePercent + protocolFeePercent > 0.2 ether) revert InvalidFeePercent();

        creatorFeePercent = _feePercent;
        emit CreatorFeePercentUpdated(_feePercent);
    }

    /// @dev Sets the signer address.
    /// Emits a {WearableSignerUpdated} event.
    function setWearableSigner(address _signer) external onlyOwner {
        wearableSigner = _signer;
        emit WearableSignerUpdated(_signer);
    }

    /// @dev Sets the operator address.
    /// Emits a {WearableOperatorUpdated} event.
    function setWearableOperator(address _operator) external onlyOwner {
        wearableOperator = _operator;
        emit WearableOperatorUpdated(_operator);
    }

    // =========================================================================
    //                          Create Wearable Logic
    // =========================================================================

    /// @dev Creates a sofamon wearable. operator only.
    /// Emits a {WearableCreated} event.
    function createWearable(CreateWearableParams calldata params) external {
        {
            if (msg.sender != wearableOperator) {
                revert InvalidOperator();
            }

            if (params.supplyFactor < 1 || params.supplyFactor > 10000) {
                revert InvalidTotalSupply();
            }

            if (params.curveFactor < 1 || params.curveFactor > 1000) {
                revert InvalidCurveFactor();
            }

            if (params.initialPriceFactor < 100 || params.initialPriceFactor > 1000) {
                revert InvalidInitialPriceFactor();
            }
        }

        // Generate wearable subject
        bytes32 wearablesSubject = keccak256(abi.encode(params.name, params.imageURI));

        // Check if wearable already exists
        if (wearables[wearablesSubject].creator != address(0)) revert WearableAlreadyCreated();

        SaleStates state = params.isPublic ? SaleStates.PUBLIC : SaleStates.PRIVATE;

        // Update wearables mapping
        WearableFactors memory factors =
            WearableFactors(params.supplyFactor, params.curveFactor, params.initialPriceFactor);
        wearables[wearablesSubject] =
            Wearable(params.creator, params.name, params.category, params.imageURI, factors, state);

        emit WearableCreated(
            params.creator, wearablesSubject, params.name, params.category, params.imageURI, factors, state
        );
    }

    // =========================================================================
    //                          Wearables Settings
    // =========================================================================
    /// @dev Sets the sale state of a wearable. operator only.
    /// Emits a {WearableSaleStateUpdated} event.
    function setWearableSalesState(bytes32 wearablesSubject, SaleStates saleState) external {
        if (msg.sender != wearableOperator) {
            revert InvalidOperator();
        }

        wearables[wearablesSubject].state = saleState;
        emit WearableSaleStateUpdated(wearablesSubject, saleState);
    }

    /// @dev Sets the sale state of multiple wearables in a batch. operator only.
    /// Emits multiple {WearableSaleStateUpdated} events.
    function batchSetWearableSalesState(bytes32[] calldata wearablesSubjects, SaleStates saleState) external {
        if (msg.sender != wearableOperator) {
            revert InvalidOperator();
        }

        for (uint256 i = 0; i < wearablesSubjects.length; i++) {
            wearables[wearablesSubjects[i]].state = saleState;
            emit WearableSaleStateUpdated(wearablesSubjects[i], saleState);
        }
    }

    // =========================================================================
    //                          Trade Wearable Logic
    // =========================================================================
    /// @dev Returns the curve of `x`
    function _curve(uint256 x, uint256 totalSupply, uint256 curveFactor, uint256 initialPriceFactor)
        private
        pure
        returns (uint256)
    {
        return (totalSupply * curveFactor * 1 ether) / (totalSupply - x) - curveFactor * 1 ether
            - initialPriceFactor * x / 1000;
    }

    /// @dev Returns the price based on `supply` and `amount`.
    function getPrice(
        uint256 supply,
        uint256 amount,
        uint256 totalSupply,
        uint256 curveFactor,
        uint256 initialPriceFactor,
        bool isBuy
    ) public pure returns (uint256) {
        if (isBuy && supply + amount >= totalSupply) {
            revert TotalSupplyExceeded();
        }

        if (!isBuy && supply >= totalSupply) {
            revert TotalSupplyExceeded();
        }

        return _curve(supply + amount, totalSupply, curveFactor, initialPriceFactor)
            - _curve(supply, totalSupply, curveFactor, initialPriceFactor);
    }

    /// @dev Returns the buy price of `amount` of `wearablesSubject`.
    function getBuyPrice(bytes32 wearablesSubject, uint256 amount) public view returns (uint256) {
        uint256 supplyFactor = wearables[wearablesSubject].factors.supplyFactor;
        uint256 curveFactor = wearables[wearablesSubject].factors.curveFactor;
        uint256 initialPriceFactor = wearables[wearablesSubject].factors.initialPriceFactor;
        return getPrice(
            wearablesSupply[wearablesSubject], amount, supplyFactor * 1 ether, curveFactor, initialPriceFactor, true
        );
    }

    /// @dev Returns the sell price of `amount` of `wearablesSubject`.
    function getSellPrice(bytes32 wearablesSubject, uint256 amount) public view returns (uint256) {
        uint256 supplyFactor = wearables[wearablesSubject].factors.supplyFactor;
        uint256 curveFactor = wearables[wearablesSubject].factors.curveFactor;
        uint256 initialPriceFactor = wearables[wearablesSubject].factors.initialPriceFactor;
        return getPrice(
            wearablesSupply[wearablesSubject] - amount,
            amount,
            supplyFactor * 1 ether,
            curveFactor,
            initialPriceFactor,
            false
        );
    }

    /// @dev Returns the buy price of `amount` of `wearablesSubject` after fee.
    function getBuyPriceAfterFee(bytes32 wearablesSubject, uint256 amount) external view returns (uint256) {
        // Get buy price before fee
        uint256 price = getBuyPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get creator fee
        uint256 creatorFee = _getCreatorFee(price);

        // Get final buy price
        return price + protocolFee + creatorFee;
    }

    /// @dev Returns the sell price of `amount` of `wearablesSubject` after fee.
    function getSellPriceAfterFee(bytes32 wearablesSubject, uint256 amount) external view returns (uint256) {
        // Get sell price before fee
        uint256 price = getSellPrice(wearablesSubject, amount);

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get creator fee
        uint256 creatorFee = _getCreatorFee(price);

        // Get final sell price
        return price - protocolFee - creatorFee;
    }

    /// @dev Returns the protocol fee.
    function _getProtocolFee(uint256 price) internal view returns (uint256) {
        return (price * protocolFeePercent) / 1 ether;
    }

    /// @dev Returns the creator fee.
    function _getCreatorFee(uint256 price) internal view returns (uint256) {
        return (price * creatorFeePercent) / 1 ether;
    }

    /// @dev Returns the nonce of `user`.
    function getUserNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    /// @dev Buys `amount` of `wearablesSubject`.
    /// Emits a {Trade} event.
    function buyWearables(bytes32 wearablesSubject, uint256 amount) external payable {
        {
            // Check if amount is greater than base unit
            if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

            // Check if amount is a multiple of the base unit
            if (amount % BASE_WEARABLE_UNIT != 0) revert AmountNotMultipleOfBaseUnit();

            // Check if wearable exists
            if (wearables[wearablesSubject].creator == address(0)) revert WearableNotCreated();

            // Check if sale state is public
            if (wearables[wearablesSubject].state != SaleStates.PUBLIC) revert InvalidSaleState();
        }

        _buyWearables(wearablesSubject, amount, true);
    }

    /// @dev Buys `amount` of `wearablesSubject` with a signature.
    /// Emits a {NonceUpdated} {Trade} event.
    function buyPrivateWearables(bytes32 wearablesSubject, uint256 amount, bytes calldata signature) external payable {
        {
            // Check if amount is greater than base unit
            if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

            // Check if amount is a multiple of the base unit
            if (amount % BASE_WEARABLE_UNIT != 0) revert AmountNotMultipleOfBaseUnit();

            // Check if wearable exists
            if (wearables[wearablesSubject].creator == address(0)) revert WearableNotCreated();

            // Check if sale state is public
            if (wearables[wearablesSubject].state != SaleStates.PRIVATE) revert InvalidSaleState();

            uint256 nonce = nonces[msg.sender];
            // Validate signature
            bytes32 hashVal = keccak256(abi.encodePacked(msg.sender, "buy", wearablesSubject, amount, nonce));
            bytes32 signedHash = hashVal.toEthSignedMessageHash();
            if (signedHash.recover(signature) != wearableSigner) {
                revert InvalidSignature();
            }

            nonces[msg.sender] += 1;

            emit NonceUpdated(msg.sender, nonces[msg.sender]);
        }

        _buyWearables(wearablesSubject, amount, false);
    }

    /// @dev Internal buys `amount` of `wearablesSubject`.
    function _buyWearables(bytes32 wearablesSubject, uint256 amount, bool isPublic) internal {
        uint256 supply = wearablesSupply[wearablesSubject];

        // Get buy price before fee
        uint256 price = getPrice(
            supply,
            amount,
            wearables[wearablesSubject].factors.supplyFactor * 1 ether,
            wearables[wearablesSubject].factors.curveFactor,
            wearables[wearablesSubject].factors.initialPriceFactor,
            true
        );

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get creator fee
        uint256 creatorFee = _getCreatorFee(price);

        // Check if user has enough funds
        if (msg.value < price + protocolFee + creatorFee) {
            revert InsufficientPayment();
        }

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] = wearablesBalance[wearablesSubject][msg.sender] + amount;
        wearablesSupply[wearablesSubject] = supply + amount;

        // Get creator fee destination
        address creatorFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(
            msg.sender, wearablesSubject, true, isPublic, amount, price, protocolFee, creatorFee, supply + amount
        );

        // Send protocol fee to protocol fee destination
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");

        //Send creator fee to creator fee destination
        (bool success2,) = creatorFeeDestination.call{value: creatorFee}("");

        // Check if all funds were sent successfully
        if (!(success1 && success2)) revert SendFundsFailed();
        
        {
            uint256 excessPayment = msg.value - price - protocolFee - creatorFee;
            // Refund excess payment to user
            if (excessPayment > 0) {
                (bool success3,) = msg.sender.call{value: excessPayment}("");
                if (!success3) {
                    revert RefundFailed();
                }
            }
        }
    }

    /// @dev Sells `amount` of `wearablesSubject`.
    /// Emits a {Trade} event.
    function sellWearables(bytes32 wearablesSubject, uint256 amount) external payable {
        {
            // Check if amount is greater than base unit
            if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

            // Check if amount is a multiple of the base unit
            if (amount % BASE_WEARABLE_UNIT != 0) revert AmountNotMultipleOfBaseUnit();

            // Check if wearable exists
            if (wearables[wearablesSubject].creator == address(0)) revert WearableNotCreated();

            // Check if sale state is public
            if (wearables[wearablesSubject].state != SaleStates.PUBLIC) revert InvalidSaleState();
        }

        _sellWearables(wearablesSubject, amount, true);
    }

    /// @dev Sells `amount` of `wearablesSubject` with a signature.
    /// Emits a {NonceUpdated} {Trade} event.
    function sellPrivateWearables(bytes32 wearablesSubject, uint256 amount, bytes calldata signature)
        external
        payable
    {
        {
            // Check if amount is greater than base unit
            if (amount < BASE_WEARABLE_UNIT) revert InsufficientBaseUnit();

            // Check if amount is a multiple of the base unit
            if (amount % BASE_WEARABLE_UNIT != 0) revert AmountNotMultipleOfBaseUnit();

            // Check if wearable exists
            if (wearables[wearablesSubject].creator == address(0)) revert WearableNotCreated();

            // Check if sale state is public
            if (wearables[wearablesSubject].state != SaleStates.PRIVATE) revert InvalidSaleState();

            uint256 nonce = nonces[msg.sender];
            // Validate signature
            bytes32 hashVal = keccak256(abi.encodePacked(msg.sender, "sell", wearablesSubject, amount, nonce));
            bytes32 signedHash = hashVal.toEthSignedMessageHash();
            if (signedHash.recover(signature) != wearableSigner) {
                revert InvalidSignature();
            }

            nonces[msg.sender] += 1;

            emit NonceUpdated(msg.sender, nonces[msg.sender]);
        }

        _sellWearables(wearablesSubject, amount, false);
    }

    /// @dev Internal sells `amount` of `wearablesSubject`.
    function _sellWearables(bytes32 wearablesSubject, uint256 amount, bool isPublic) internal {
        uint256 supply = wearablesSupply[wearablesSubject];

        // Get sell price before fee
        uint256 price = getPrice(
            supply - amount,
            amount,
            wearables[wearablesSubject].factors.supplyFactor * 1 ether,
            wearables[wearablesSubject].factors.curveFactor,
            wearables[wearablesSubject].factors.initialPriceFactor,
            false
        );

        // Get protocol fee
        uint256 protocolFee = _getProtocolFee(price);

        // Get creator fee
        uint256 creatorFee = _getCreatorFee(price);

        // Check if user has enough amount for sale
        if (wearablesBalance[wearablesSubject][msg.sender] < amount) {
            revert InsufficientHoldings();
        }

        // Update wearables balance and supply
        wearablesBalance[wearablesSubject][msg.sender] = wearablesBalance[wearablesSubject][msg.sender] - amount;
        wearablesSupply[wearablesSubject] = supply - amount;

        // Get creator fee destination
        address creatorFeeDestination = wearables[wearablesSubject].creator;

        emit Trade(
            msg.sender, wearablesSubject, false, isPublic, amount, price, protocolFee, creatorFee, supply - amount
        );

        // Send sell funds to seller
        (bool success1,) = msg.sender.call{value: price - protocolFee - creatorFee}("");

        // Send protocol fee to protocol fee destination
        (bool success2,) = protocolFeeDestination.call{value: protocolFee}("");

        // Send creator fee to creator fee destination
        (bool success3,) = creatorFeeDestination.call{value: creatorFee}("");

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

        // Check if amount is a multiple of the base unit
        if (amount % BASE_WEARABLE_UNIT != 0) revert AmountNotMultipleOfBaseUnit();

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
