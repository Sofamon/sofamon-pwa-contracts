// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IBlast {
    // configure yield
    function configureAutomaticYield() external;

    // configure gas
    function configureClaimableGas() external;

    // configure governor
    function configureGovernor(address _governor) external;

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);

    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips)
        external
        returns (uint256);

    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
}
