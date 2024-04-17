// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {SofamonWearables} from "../src/SofamonWearables.sol";
import {SofamonWearablesV2} from "../src/SofamonWearablesV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SofamonWearablesScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployedProxy = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        SofamonWearablesV2 sofaV2 = new SofamonWearablesV2();
        console.log("SofamonWearablesV2 implementation deployed at:", address(sofaV2));
        SofamonWearables proxy = SofamonWearables(deployedProxy);
        proxy.upgradeTo(address(sofaV2));
        console.log("SofamonWearables proxy upgraded to:", address(sofaV2));
        vm.stopBroadcast();
    }
}
