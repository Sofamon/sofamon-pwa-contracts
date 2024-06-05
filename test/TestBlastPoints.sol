// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBlastPoints} from "../src/IBlastPoints.sol";

contract TestBlastPoints is IBlastPoints {
    // configure points operator
    function configurePointsOperator(address operator) external {}
}
