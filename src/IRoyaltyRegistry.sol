// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IRoyaltyRegistry {
    struct RoyaltyInfo {
        uint256 totalRoyaltyPercentage; // ie 5e18 (5%)
        RoyaltyRecipientInfo[] recipientInfo;
    }

    struct RoyaltyRecipientInfo {
        address recipient;
        uint96 percentage; // the actual percentage of the sale a recipient should get
    }

    function registerContractRoyaltyInfo(
        address contractAddress,
        uint256 totalRoyaltyPercentage,
        RoyaltyRecipientInfo[] calldata recipientInfo
    ) external;

    function registerTokenRoyaltyInfo(
        address contractAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata totalRoyaltyPercentages,
        RoyaltyRecipientInfo[][] calldata recipientInfos
    ) external;

    function removeContractRoyalties(address contractAddress) external;

    function removeAllTokenRoyalties(address contractAddress) external;

    function removeSpecificTokenRoyalties(
        address contractAddress,
        uint256[] calldata tokenIds
    ) external;

    function enableOverrideRoyaltyInfoForToken(
        address contractAddress,
        uint256[] calldata tokenIds
    ) external;

    function disableOverrideRoyaltyInfoForToken(
        address contractAddress,
        uint256[] calldata tokenIds
    ) external;

    function getRoyaltyInfoForToken(
        address contractAddress,
        uint256 tokenId
    ) external view returns (RoyaltyInfo memory);

    function getRoyaltyInfoForTokens(
        address contractAddress,
        uint256[] calldata tokenIds
    ) external view returns (RoyaltyInfo[] memory);

    function calculateRoyaltyInfoForTokenSale(
        address contractAddress,
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (uint256, address[] memory, uint256[] memory);
}
