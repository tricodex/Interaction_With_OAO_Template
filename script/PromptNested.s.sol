// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PromptNestedInference} from "../src/PromptNestedInference.sol";
import {IAIOracle} from "OAO/contracts/interfaces/IAIOracle.sol";

contract PromptScript is Script {
    address public constant OAO_PROXY = 0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(privateKey);
        PromptNestedInference promptNestedInference = new PromptNestedInference(IAIOracle(OAO_PROXY));
        console2.log("PromptNestedInference deployed at:", address(promptNestedInference));
        vm.stopBroadcast();
    }
}