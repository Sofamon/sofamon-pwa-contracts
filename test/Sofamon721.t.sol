// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Sofamon721.sol";

contract Sofamon721Test is Test {
    Sofamon721 public nft;
    function setUp() public {
       nft = new Sofamon721(0x5E113EDC0eaf00699889FC510DB121308bBA1261, 0x5300Ba71395230dAaD8350ec6568cF16E0511c13);
    }
}
