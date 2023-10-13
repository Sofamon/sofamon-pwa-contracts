// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";

contract SofamonSharesTest is Test {
    SofamonWearables public shares;
    function setUp() public {
       shares = new SofamonWearables();
    }
}
