// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBlastPoints {
    // configure points operator
    function configurePointsOperator(address operator) external;

    // configure points operator on behalf
    function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}
