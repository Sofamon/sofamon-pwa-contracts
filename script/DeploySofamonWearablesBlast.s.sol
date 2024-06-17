// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {TestBlast} from "../test/TestBlast.sol";
import {TestBlastPoints} from "../test/TestBlastPoints.sol";
import {SofamonWearablesBlast} from "../src/SofamonWearablesBlast.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SofamonWearablesScript is Script {
    address BLAST = 0x4300000000000000000000000000000000000002;
    address BLAST_POINTS = 0x2fc95838c71e76ec69ff817983BFf17c710F34E0;

    function run() external {
        TestBlast testBlast = new TestBlast();
        vm.etch(BLAST, address(testBlast).code);

        TestBlastPoints testBlastPoints = new TestBlastPoints();
        vm.etch(BLAST_POINTS, address(testBlastPoints).code);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address pointsOperator = vm.envAddress("POINTS_OPERATOR_ADDRESS");
        address wearableOperator = vm.envAddress("WEARABLE_OPERATOR_ADDRESS");
        address signer = vm.envAddress("SIGNER_ADDRESS");
        SofamonWearablesBlast sofa = new SofamonWearablesBlast();
        console.log("SofamonWearablesBlast implementation deployed at:", address(sofa));
        ERC1967Proxy proxy = new ERC1967Proxy(address(sofa), "");
        SofamonWearablesBlast(address(proxy)).initialize(governor, pointsOperator, wearableOperator, signer);
        console.log("SofamonWearablesBlast proxy deployed at:", address(proxy));
        vm.stopBroadcast();
    }
}
