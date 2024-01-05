// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Errors
error InvalidSignature();
error InsufficientPayment();
error SupplyExceeded();
error WithdrawFailed();
error InvalidAuctionSetup();
error AuctionMintNotOpen();
error InsufficientFunds();
error RefundFailed();
error AllowlistMintNotOpen();
error InvalidNewInvocations();
error PublicMintNotOpen();
error InvalidPublicSetup();
error InvalidAllowlistSetup();

/**
 * @title Sofamon721V1
 * @author lixingyu.eth <@0xlxy>
 */
contract Sofamon721V1 is ERC721, Ownable2Step {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 constant ONE_MILLION = 1_000_000;
    uint24 constant ONE_MILLION_UINT24 = 1_000_000;

    // starting (initial) wearable ID on this contract
    uint256 public immutable startingWearableId;

    // next wearable ID to be created
    uint248 private _nextWearableId;

    // default base URI to initialize all new wearable wearableBaseURI values to
    string public defaultBaseURI;

    address public mintSigner;

    struct AllowlistInfo {
        uint32 allowlistStartTime;
        uint32 allowlistEndTime;
        uint64 allowlistPrice;
    }

    struct PublicInfo {
        uint32 publicStartTime;
        uint32 publicEndTime;
        uint64 publicPrice;
    }

    struct AuctionInfo {
        uint32 auctionSaleStartTime;
        uint64 auctionStartPrice;
        uint64 auctionEndPrice;
        uint32 auctionPriceCurveLength;
        uint32 auctionDropInterval;
    }

    struct Wearable {
        uint24 invocations;
        uint24 maxInvocations;
        // max uint64 ~= 1.8e19 sec ~= 570 billion years
        uint64 completedTimestamp;
        string name;
        string artist;
        string description;
        string wearableBaseURI;
        AllowlistInfo allowlistInfo;
        PublicInfo publicInfo;
        AuctionInfo auctionInfo;
    }

    // wearableId => wearable info
    mapping(uint256 => Wearable) public wearables;

    modifier onlyNonZeroAddress(address _address) {
        require(_address != address(0), "Must input non-zero address");
        _;
    }

    modifier onlyNonEmptyString(string memory _string) {
        require(bytes(_string).length != 0, "Must input non-empty string");
        _;
    }

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(ownerOf(_tokenId) != address(0), "Token ID does not exist");
        _;
    }

    modifier onlyValidWearableId(uint256 _wearableId) {
        require(
            (_wearableId >= startingWearableId) &&
                (_wearableId < _nextWearableId),
            "Wearable ID does not exist"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint248 _startingWearableId,
        address _owner,
        address _signer
    ) ERC721(_name, _symbol) Ownable(_owner) {
        startingWearableId = uint256(_startingWearableId);
        mintSigner = _signer;
    }

    // =========================================================================
    //                             Public Mint
    // =========================================================================
    function publicMint(
        address to,
        uint256 wearableId,
        uint8 qty,
        bytes calldata signature
    ) external payable returns (uint256[] memory) {
        Wearable storage wearable = wearables[wearableId];
        PublicInfo memory info = wearable.publicInfo;
        uint256 publicMintPrice = info.publicPrice;
        uint24 invocationsBefore = wearable.invocations;
        uint24 invocationsAfter = invocationsBefore + qty;
        uint24 maxInvocations = wearable.maxInvocations;
        // check mint state
        if (
            info.publicStartTime == 0 ||
            block.timestamp < info.publicStartTime ||
            block.timestamp >= info.publicEndTime
        ) {
            revert PublicMintNotOpen();
        }

        // check payment
        if (msg.value < publicMintPrice * qty) revert InsufficientPayment();

        // check supply
        if (invocationsAfter > maxInvocations) revert SupplyExceeded();
        wearable.invocations = invocationsAfter;

        // validate signature
        bytes32 hashVal = keccak256(
            abi.encodePacked(msg.sender, wearableId, qty)
        );
        bytes32 signedHash = hashVal.toEthSignedMessageHash();
        if (signedHash.recover(signature) != mintSigner)
            revert InvalidSignature();

        // mark project as completed if hit max invocations
        if (invocationsAfter == maxInvocations) {
            _completeProject(wearableId);
        }

        // mint tokens
        uint256[] memory tokenIds = new uint256[](qty);
        for (uint8 i = 0; i < qty; i++) {
            uint256 thisTokenId = (wearableId * ONE_MILLION) +
                invocationsBefore +
                i;
            _mint(to, thisTokenId);
            tokenIds[i] = thisTokenId;
        }

        // emit Mint(to, qty);
        return tokenIds;
    }

    function setPublicParams(
        uint256 _wearableId,
        uint32 _publicStartTime,
        uint32 _publicEndTime,
        uint64 _publicPrice
    ) external onlyOwner {
        if (_publicStartTime == 0 || _publicEndTime == 0 || _publicPrice == 0) {
            revert InvalidPublicSetup();
        }
        if (_publicStartTime >= _publicEndTime) {
            revert InvalidPublicSetup();
        }
        wearables[_wearableId].publicInfo = PublicInfo(
            _publicStartTime,
            _publicEndTime,
            _publicPrice
        );
    }

    // =========================================================================
    //                             Allowlist Mint
    // =========================================================================

    /**
     * Paid allowlist mint function.
     * @param to Address that will receive the NFTs
     * @param qty Number of NFTs to mint
     * @param signature Signature generated from the backend
     */
    function allowlistMint(
        address to,
        uint256 wearableId,
        uint8 qty,
        bytes calldata signature
    ) external payable returns (uint256[] memory) {
        Wearable storage wearable = wearables[wearableId];
        AllowlistInfo memory info = wearable.allowlistInfo;
        uint256 allowlistMintPrice = info.allowlistPrice;
        uint24 invocationsBefore = wearable.invocations;
        uint24 invocationsAfter = invocationsBefore + qty;
        uint24 maxInvocations = wearable.maxInvocations;
        // check mint state
        if (
            info.allowlistStartTime == 0 ||
            block.timestamp < info.allowlistStartTime ||
            block.timestamp >= info.allowlistEndTime
        ) {
            revert AllowlistMintNotOpen();
        }

        // check payment
        if (msg.value < allowlistMintPrice * qty) revert InsufficientPayment();

        // check supply
        if (invocationsAfter > maxInvocations) revert SupplyExceeded();
        wearable.invocations = invocationsAfter;

        // validate signature
        bytes32 hashVal = keccak256(
            abi.encodePacked(msg.sender, wearableId, qty)
        );
        bytes32 signedHash = hashVal.toEthSignedMessageHash();
        if (signedHash.recover(signature) != mintSigner)
            revert InvalidSignature();

        // mark project as completed if hit max invocations
        if (invocationsAfter == maxInvocations) {
            _completeProject(wearableId);
        }

        // mint tokens
        uint256[] memory tokenIds = new uint256[](qty);
        for (uint8 i = 0; i < qty; i++) {
            uint256 thisTokenId = (wearableId * ONE_MILLION) +
                invocationsBefore +
                i;
            _mint(to, thisTokenId);
            tokenIds[i] = thisTokenId;
        }

        // emit Mint(to, qty);
        return tokenIds;
    }

    // Allowlist price to match starting price of dutch auction
    function setAllowlistParams(
        uint256 _wearableId,
        uint32 _allowlistStartTime,
        uint32 _allowlistEndTime,
        uint64 _allowlistPrice
    ) external onlyOwner {
        if (_allowlistStartTime == 0 || _allowlistEndTime == 0) {
            revert InvalidAllowlistSetup();
        }
        if (_allowlistStartTime >= _allowlistEndTime) {
            revert InvalidAllowlistSetup();
        }
        wearables[_wearableId].allowlistInfo = AllowlistInfo(
            _allowlistStartTime,
            _allowlistEndTime,
            _allowlistPrice
        );
    }

    // =========================================================================
    //                             Dutch Auction
    // =========================================================================
    function getAuctionPrice(uint256 wearableId) public view returns (uint256) {
        AuctionInfo memory info = wearables[wearableId].auctionInfo;
        // if auction does not exist, return 0
        if (block.timestamp < info.auctionSaleStartTime) {
            return info.auctionStartPrice;
        }
        if (
            block.timestamp - info.auctionSaleStartTime >=
            info.auctionPriceCurveLength
        ) {
            return info.auctionEndPrice;
        } else {
            uint256 steps = (block.timestamp - info.auctionSaleStartTime) /
                info.auctionDropInterval;
            uint256 auctionDropPerStep = (info.auctionStartPrice -
                info.auctionEndPrice) /
                (info.auctionPriceCurveLength / info.auctionDropInterval);
            return info.auctionStartPrice - (steps * auctionDropPerStep);
        }
    }

    modifier isEOA() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function auctionMint(
        address to,
        uint256 wearableId,
        uint8 qty,
        bytes calldata signature
    ) external payable isEOA returns (uint256[] memory) {
        Wearable storage wearable = wearables[wearableId];
        AuctionInfo memory info = wearable.auctionInfo;

        uint24 invocationsBefore = wearable.invocations;
        uint24 invocationsAfter = invocationsBefore + qty;
        uint24 maxInvocations = wearable.maxInvocations;

        // check mint state
        if (
            info.auctionSaleStartTime == 0 ||
            block.timestamp < info.auctionSaleStartTime
        ) {
            revert AuctionMintNotOpen();
        }

        // check supply
        if (invocationsAfter > maxInvocations) revert SupplyExceeded();
        wearable.invocations = invocationsAfter;

        // validate signature
        bytes32 hashVal = keccak256(
            abi.encodePacked(msg.sender, wearableId, qty)
        );
        bytes32 signedHash = hashVal.toEthSignedMessageHash();
        if (signedHash.recover(signature) != mintSigner)
            revert InvalidSignature();

        // check payment
        uint256 totalCost = getAuctionPrice(wearableId) * qty;
        if (msg.value < totalCost) {
            revert InsufficientFunds();
        }

        // mint tokens
        uint256[] memory tokenIds = new uint256[](qty);
        for (uint8 i = 0; i < qty; i++) {
            uint256 thisTokenId = (wearableId * ONE_MILLION) +
                invocationsBefore +
                i;
            _mint(to, thisTokenId);
            tokenIds[i] = thisTokenId;
        }

        // refund excess payment
        if (msg.value > totalCost) {
            (bool sent, ) = msg.sender.call{value: msg.value - totalCost}("");
            if (!sent) {
                revert RefundFailed();
            }
        }

        // emit Mint(to, qty);
        return tokenIds;
    }

    function setAuctionParams(
        uint256 _wearableId,
        uint32 _startTime,
        uint64 _startPriceWei,
        uint64 _endPriceWei,
        uint32 _priceCurveNumSeconds,
        uint32 _dropIntervalNumSeconds
    ) public onlyOwner {
        if (
            _startTime != 0 &&
            (_startPriceWei == 0 ||
                _priceCurveNumSeconds == 0 ||
                _dropIntervalNumSeconds == 0)
        ) {
            revert InvalidAuctionSetup();
        }
        wearables[_wearableId].auctionInfo = AuctionInfo(
            _startTime,
            _startPriceWei,
            _endPriceWei,
            _priceCurveNumSeconds,
            _dropIntervalNumSeconds
        );
    }

    function setAuctionSaleStartTime(
        uint256 wearableId,
        uint32 timestamp
    ) external onlyOwner {
        AuctionInfo memory info = wearables[wearableId].auctionInfo;
        if (
            timestamp != 0 &&
            (info.auctionStartPrice == 0 ||
                info.auctionPriceCurveLength == 0 ||
                info.auctionDropInterval == 0)
        ) {
            revert InvalidAuctionSetup();
        }
        wearables[wearableId].auctionInfo.auctionSaleStartTime = timestamp;
    }

    // =========================================================================
    //                             Wearable Settings
    // =========================================================================

    /**
     * @notice Adds new wearable `_projectName` by `_artistAddress`.
     * @param _wearableName Project name.
     * @param _artistAddress Artist's address.
     * @dev token price now stored on minter
     */
    function addWearable(
        string memory _wearableName,
        address payable _artistAddress
    ) external onlyOwner {
        uint256 wearableId = _nextWearableId;
        wearables[wearableId].name = _wearableName;
        wearables[wearableId].maxInvocations = ONE_MILLION_UINT24;
        wearables[wearableId].wearableBaseURI = defaultBaseURI;

        _nextWearableId = uint248(wearableId) + 1;
        // emit WearableUpdated(wearableId, FIELD_PROJECT_CREATED);
    }

    function updateWearableName(uint256 _wearableId, string memory _name)
        external
        onlyOwner
        onlyValidWearableId(_wearableId)
        onlyNonEmptyString(_name)
    {
        wearables[_wearableId].name = _name;
        // emit WearableUpdated(_wearableId, FIELD_PROJECT_NAME);
    }

    function updateWearableArtist(
        uint256 _wearableId,
        string memory _artist
    ) external onlyOwner onlyValidWearableId(_wearableId) {
        wearables[_wearableId].artist = _artist;
        // emit WearableUpdated(_wearableId, FIELD_PROJECT_ARTIST);
    }

    function updateWearableDescription(
        uint256 _wearableId,
        string memory _description
    ) external onlyOwner onlyValidWearableId(_wearableId) {
        wearables[_wearableId].description = _description;
        // emit WearableUpdated(_wearableId, FIELD_PROJECT_DESCRIPTION);
    }

    function updateWearableBaseURI(
        uint256 _wearableId,
        string memory _wearableBaseURI
    ) external onlyOwner onlyValidWearableId(_wearableId) {
        wearables[_wearableId].wearableBaseURI = _wearableBaseURI;
        // emit WearableUpdated(_wearableId, FIELD_PROJECT_BASE_URI);
    }

    /**
     * Owner-only function to set the collection supply. This value can only be decreased.
     */
    function updateMaxInvocations(
        uint256 _wearableId,
        uint24 _maxInvocations
    ) external onlyOwner {
        Wearable storage wearable = wearables[_wearableId];
        if (_maxInvocations >= wearable.maxInvocations)
            revert InvalidNewInvocations();
        if (_maxInvocations < wearable.invocations)
            revert InvalidNewInvocations();
        wearable.maxInvocations = _maxInvocations;
        // emit ProjectUpdated(_projectId, FIELD_PROJECT_MAX_INVOCATIONS);

        // register completed timestamp if action completed the project
        if (_maxInvocations == wearable.invocations) {
            _completeProject(_wearableId);
        }
    }

    /**
     * @notice Next wearable ID to be created on this contract.
     * @return uint256 Next wearable ID.
     */
    function nextWearableId() external view returns (uint256) {
        return _nextWearableId;
    }

    /**
     * @notice Internal function to complete a project.
     * @param _wearableId Wearable ID to be completed.
     */
    function _completeProject(uint256 _wearableId) internal {
        wearables[_wearableId].completedTimestamp = uint64(block.timestamp);
    }

    // =========================================================================
    //                             Mint Settings
    // =========================================================================

    /**
     * Owner-only function to set the mint signer.
     * @param _signer New mint signer
     */
    function setMintSigner(address _signer) external onlyOwner {
        mintSigner = _signer;
    }

    /**
     * Owner-only function to withdraw funds in the contract to a destination address.
     * @param receiver Destination address to receive funds
     */
    function withdrawFunds(address receiver) external onlyOwner {
        (bool sent, ) = receiver.call{value: address(this).balance}("");
        if (!sent) {
            revert WithdrawFailed();
        }
    }
}
