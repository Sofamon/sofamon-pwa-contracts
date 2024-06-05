// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBlast {
    // configure yield
    function configureAutomaticYield() external;

    // configure gas
    function configureClaimableGas() external;

    // configure governor
    function configureGovernor(address _governor) external;
}
