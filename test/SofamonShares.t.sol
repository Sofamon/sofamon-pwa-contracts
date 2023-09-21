// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SofamonShares.sol";

contract SofamonSharesTest is Test {
    SofamonShares public shares;
    function setUp() public {
       shares = new SofamonShares();
    }
}
