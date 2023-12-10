// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";

contract SofamonSharesTest is Test {
    SofamonWearables public shares;
    function setUp() public {
       shares = new SofamonWearables(0x7d39be0b147D1148251f734d8adF5972DbEcF9dD);
    }
}
