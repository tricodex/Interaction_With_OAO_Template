// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {Prompt} from "../src/Prompt.sol";
import {AIOracle} from "../src/AIOracle.sol";
import {OraSepoliaAddresses} from "./OraSepoliaAddresses.t.sol";
import "forge-std/console.sol";

/**
 *  TEST SCENARIOS
 * 1. test the setup (check aiOracle, owner, gasLimits)
 * 2. test the gas limit setting
    - revert if not owner
    - check the state change after the update
 * 3. test OAO request
    - check if PromptRequest is emmited
    - check the event data
    - check state updates (access the request variable and check values)
 * 4. check if aiOracleCallback is called
    - need to wait few blocks for the OPML to finish computation
    - mock the output and call method directly
    - impersonate the caller and check the modifier (only OAO should be able to call)
 * 5. do all the tests on all the supported models
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

    function test_SetUp() public {
        assertNotEq(address(prompt), address(0));
        // assertEq(prompt.owner(), address(this));
        assertEq(address(prompt.aiOracle()), OAO_PROXY);
        assertEq(prompt.callbackGasLimit(STABLE_DIFUSION_ID), 500_000);
        assertEq(prompt.callbackGasLimit(LLAMA_ID), 5_000_000);
        assertEq(prompt.callbackGasLimit(GROK_ID), 5_000_000);
    }

    function test_CallbackGasLimit() public {
        vm.startPrank(address(123));
        vm.expectRevert("Only owner");
        prompt.setCallbackGasLimit(11, 3_000_000);
        vm.stopPrank();

        prompt.setCallbackGasLimit(50, 3_000_000);
        assertEq(prompt.callbackGasLimit(50), 3_000_000);

        prompt.setCallbackGasLimit(11, 3_000_000);
        assertEq(prompt.callbackGasLimit(11), 3_000_000);

        prompt.setCallbackGasLimit(9, 3_000_000);
        assertEq(prompt.callbackGasLimit(9), 3_000_000); 
    }

    function test_OAOInteraction() public {
        vm.expectEmit(false, false, false, false);
        //check if requestCallback method is executed
        emit promptRequest(3355, address(this), modelId, input);
        //check if OPML node called aiOracleCallback method
        emit promptsUpdated(3355, modelId, input, "", "");
        prompt.calculateAIResult{value: prompt.estimateFee(11)}(modelId, input);

        //wait for the next block

        // (,uint256 modelId,bytes memory request_input,) = prompt.requests(3357);
        // string memory output = prompt.getAIResult(modelId, string(request_input));
        // assertNotEq(output, "");
        // console.log(output);
    }
}
