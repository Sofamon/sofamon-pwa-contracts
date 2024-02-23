// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import {IBlast} from "../src/IBlast.sol";

contract TestBlast is IBlast {
    // configure yield
    function configureAutomaticYield() external {}

    // configure gas
    function configureClaimableGas() external {}

    // configure governor
    function configureGovernor(address _governor) external {}

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256) {}

    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips)
        external
        returns (uint256)
    {}

    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256) {}
}
