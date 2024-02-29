// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {TestBlast} from "../test/TestBlast.sol";
import {SofamonWearables} from "../src/SofamonWearables.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SofamonWearablesScript is Script {
    address BLAST = 0x4300000000000000000000000000000000000002;

    function run() external {
        TestBlast testBlast = new TestBlast();
        vm.etch(BLAST, address(testBlast).code);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address operator = vm.envAddress("OPERATOR_ADDRESS");
        address signer = vm.envAddress("SIGNER_ADDRESS");
        SofamonWearables sofa = new SofamonWearables();
        console.log("SofamonWearables implementation deployed at:", address(sofa));
        ERC1967Proxy proxy = new ERC1967Proxy(address(sofa), "");
        SofamonWearables(address(proxy)).initialize(governor, operator, signer);
        console.log("SofamonWearables proxy deployed at:", address(proxy));
        vm.stopBroadcast();
    }
}
