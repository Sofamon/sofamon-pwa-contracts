// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {SofamonWearables} from "../src/SofamonWearables.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SofamonWearablesScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address wearableOperator = vm.envAddress("WEARABLE_OPERATOR_ADDRESS");
        address signer = vm.envAddress("SIGNER_ADDRESS");
        SofamonWearables sofa = new SofamonWearables();
        console.log("SofamonWearables implementation deployed at:", address(sofa));
        ERC1967Proxy proxy = new ERC1967Proxy(address(sofa), "");
        SofamonWearables(address(proxy)).initialize(wearableOperator, signer);
        console.log("SofamonWearables proxy deployed at:", address(proxy));
        vm.stopBroadcast();
    }
}
