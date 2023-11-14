// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";

contract SofamonSharesTest is Test {
    SofamonWearables public shares;
    function setUp() public {
       shares = new SofamonWearables();
    }
}
