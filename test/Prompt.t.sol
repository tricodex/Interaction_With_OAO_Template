// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {Prompt} from "../src/Prompt.sol";
import {AIOracle} from "../src/AIOracle.sol";
import {OraSepoliaAddresses} from "./OraSepoliaAddresses.t.sol";
import "forge-std/console.sol";

/**
 *  TEST SCENARIOS
 *  1. test estimateFee method
 *  2. test CalculateAIReusult method
 *      assert for the emmited promptRequested event
*/

contract PromptTest is Test, OraSepoliaAddresses {
    event promptRequest(
        uint256 requestId,
        address sender, 
        uint256 modelId,
        string prompt
    );

    event AICallbackRequest(
        address indexed account,
        uint256 indexed requestId,
        uint256 modelId,
        bytes input,
        address callbackContract,
        uint64 gasLimit,
        bytes callbackData
    );

    Prompt public prompt;
    AIOracle public aiOracle;
    uint256 public modelId;
    string public input;
    string public sepoliaRpc;
    uint256 public forkId;

    function setUp() public {
        sepoliaRpc = vm.envString("SEPOLIA_RPC");
        forkId = vm.createSelectFork(sepoliaRpc);

        prompt = new Prompt(AIOracle(OAO_PROXY));
        modelId = 11; //llama
        input = "Tell me how to prepare eggs";
    }

    function test_OAOInteraction() public {
        vm.expectEmit(true, true, false, false);
        emit promptRequest(3355, address(this), modelId, input);
        prompt.calculateAIResult{value: prompt.estimateFee(11)}(modelId, input);
    }
}
