// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IFactory {
    function fee() external view returns (uint256);

    function feeReceiver() external view returns (address);

    function currentOrderbook721Version() external view returns (uint256);

    // returns the orderbook for a given collection
    function orderbooks721(
        uint256 version,
        address collection
    ) external view returns (address);

    // returns the orderbook for a given collection
    function orderbooks1155(
        uint256 version,
        address collection
    ) external view returns (address);

    function createOrderbook721(address collection) external returns (address);

    function createOrderbook1155(address collection) external returns (address);

    function isOrderbook721(
        address collection,
        address orderbook
    ) external view returns (bool);

    function isOrderbook1155(
        address collection,
        address orderbook
    ) external view returns (bool);
}