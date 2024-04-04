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

    event promptsUpdated(
        uint256 requestId,
        uint256 modelId,
        string input,
        string output,
        bytes callbackData
    );

    Prompt prompt;
    AIOracle aiOracle;
    uint256 modelId;
    string input;
    string sepoliaRpc;
    uint256 forkId;

    function setUp() public {
        sepoliaRpc = vm.envString("SEPOLIA_RPC");
        forkId = vm.createSelectFork(sepoliaRpc);

        prompt = new Prompt(AIOracle(OAO_PROXY));
        modelId = 11; //llama
        input = "What is a good use case for on-chain AI?";
    }

    function test_OAOInteraction() public {
        vm.expectEmit(false, false, false, false);
        //check if requestCallback method is executed
        emit promptRequest(3355, address(this), modelId, input);
        //check if OPML node called aiOracleCallback method
        emit promptsUpdated(3355, modelId, input, "", "");
        prompt.calculateAIResult{value: prompt.estimateFee(11)}(modelId, input);

        // (,,bytes memory request_input,) = prompt.requests(3357);
        // string memory output = prompt.getAIResult(modelId, string(request_input));
        // assertNotEq(output, "");
        // console.log(output);
    }

    function test_CallbackGasLimit() public {
        uint64 oldLimit = prompt.callbackGasLimit(modelId);
        assertEq(oldLimit, 5_000_000);
        vm.expectRevert("Only owner");
        vm.prank(address(123));
        prompt.setCallbackGasLimit(modelId, 3_000_000);
        vm.stopPrank();

        prompt.setCallbackGasLimit(modelId, 3_000_000);
        uint64 newLimit = prompt.callbackGasLimit(modelId);
        assertEq(newLimit, 3_000_000);   
    }
}
