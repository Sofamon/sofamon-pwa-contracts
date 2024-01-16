// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IFactory} from "./IFactory.sol";
import {IRoyaltyRegistry} from "./IRoyaltyRegistry.sol";
import {ERC721C} from "creator-token-contracts/erc721c/ERC721C.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721OpenZeppelin} from "creator-token-contracts/token//erc721/ERC721OpenZeppelin.sol";

// name of standard TBD, we use ERC721C transfer validation logic as our default whitelisting logic.
// however, palette will bypass this logic.
abstract contract ERC721Frame is ERC721C, Ownable {
    error InvalidInputs();

    event PaletteApproval(
        address indexed collection,
        address indexed owner,
        bool approved
    );

    // enshrined factory address
    IFactory public constant FACTORY =
        IFactory(0x0000000000000000000000000000000000000100);

    // enshrined royalty registry address
    IRoyaltyRegistry public constant ROYALTY_REGISTRY =
        IRoyaltyRegistry(0x0000000000000000000000000000000000000101);

    // collection can turn on/off palette whitelist
    bool public paletteApproved;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721OpenZeppelin(name, symbol) {
        // whitelist palette
        paletteApproved = true;

        // auto create the initial orderbook
        FACTORY.createOrderbook721(address(this));

        // this will subscribe collection to whitelist group id 1 which will be a whitelist chain owners own
        // and can add to
        setToDefaultSecurityPolicy();
    }

    // can toggle palette approval
    function setPaletteApproval(bool approved) external virtual {
        _requireCallerIsContractOwner();

        paletteApproved = approved;

        emit PaletteApproval(address(this), msg.sender, approved);
    }

    // modify prehook to whitelist palette and bypass transfer validator logic
    function _preValidateTransfer(
        address caller,
        address from,
        address to,
        uint256 tokenId,
        uint256 value
    ) internal virtual override {
        if (paletteApproved) {
            address isOrderbook = FACTORY.isOrderbook721(address(this), caller);

            // confirm it is palette, return early
            if (isOrderbook) {
                return;
            }
        }

        // else check default whitelist operators
        super._preValidateTransfer(caller, from, to, tokenId, value);
    }

    // there is an explicit approval palette must receive
    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        if (paletteApproved) {
            if (operator == getPaletteOrderbookForCollection()) {
                return true;
            }
        }

        return super.isApprovedForAll(owner, operator);
    }

    // 721C override
    function _requireCallerIsContractOwner() internal view virtual override {
        _checkOwner();
    }

    // example of interacting with royalty registry via code
    function updateCollectionRoyalties(
        uint256 totalRoyaltyPercentage,
        address[] calldata recipients,
        uint96[] calldata recipientPercentages
    ) external {
        _requireCallerIsContractOwner();

        if (recipients.length != recipientPercentages.length)
            revert InvalidInputs();

        IRoyaltyRegistry.RoyaltyRecipientInfo[]
            memory info = new IRoyaltyRegistry.RoyaltyRecipientInfo[](
                recipients.length
            );
        for (uint256 i = 0; i < recipients.length; ++i) {
            info[i] = IRoyaltyRegistry.RoyaltyRecipientInfo(
                recipients[i],
                recipientPercentages[i]
            );
        }

        ROYALTY_REGISTRY.registerContractRoyaltyInfo(
            address(this),
            totalRoyaltyPercentage,
            info
        );
    }
}
