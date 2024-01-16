// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721Frame} from "./ERC721Frame.sol";

contract Sofamon721 is ERC721Frame {
    using Strings for uint256;

    constructor(
        string memory name,
        string memory symbol,
        string memory uri
    ) ERC721Frame(name, symbol) {
        baseUri = uri;
    }

    uint256 currId;
    string public baseUri;

    function mint(uint256 amt) external {
        for (uint256 i = 0; i < amt; ++i) {
            _mint(msg.sender, currId++);
        }
    }

    function mintTo(address to, uint256 amt) external {
        for (uint256 i = 0; i < amt; ++i) {
            _mint(to, currId++);
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return string.concat(baseUri, tokenId.toString());
    }
}
