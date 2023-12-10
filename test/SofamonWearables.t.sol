// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SofamonWearables.sol";

contract SofamonSharesTest is Test {
    SofamonWearables public shares;
    function setUp() public {
       shares = new SofamonWearables(0x5300Ba71395230dAaD8350ec6568cF16E0511c13);
    }
}
