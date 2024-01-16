// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";

contract SofamonWearablesTest is Test {
    SofamonWearables public shares;
    function setUp() public {
       shares = new SofamonWearables("TEST", "TEST", "TEST");
    }
}
