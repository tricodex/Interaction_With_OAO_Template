// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {PromptWithCallbackData} from "../src/PromptWithCallbackData.sol";
import {IAIOracle} from "../src/interfaces/IAIOracle.sol";
import {OraSepoliaAddresses} from "./OraSepoliaAddresses.t.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "forge-std/console.sol";

/**
 *  TEST SCENARIOS
 * 1. test the setup (check aiOracle, owner, gasLimits)
 * 2. test the gas limit setting
    - revert if not owner
    - check the state change after the update
 * 3. test OAO request
    - check if PromptRequest is emitted
    - check the event data
    - check state updates (access the requests variable and check values)
 * 4. check if aiOracleCallback is called
    - need to wait few blocks for the OPML to finish computation
    - mock the output and call method directly
    - impersonate the caller and check the modifier (only OAO should be able to call)
 * 5. do all the tests on all the supported models
*/

contract PromptWithCallbackDataTest is Test, OraSepoliaAddresses, IERC721Receiver {
    event promptRequest(
        uint256 requestId,
        address sender, 
        uint256 modelId,
        string prompt
    );

    event promptsUpdated(
        uint256 requestId,
        uint256 modelId,
        string input,
        string output,
        bytes callbackData
    );

    PromptWithCallbackData prompt;
    string rpc;
    uint256 forkId;

    ///@notice implementing this method to be able to receive ERC721 token
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }

    function setUp() public {
        rpc = vm.envString("SEPOLIA_RPC");
        forkId = vm.createSelectFork(rpc);
        prompt = new PromptWithCallbackData(IAIOracle(OAO_PROXY));
    }

    function test_SetUp() public {
        assertNotEq(address(prompt), address(0));
        assertEq(prompt.owner(), address(this));
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
        vm.expectRevert("insufficient fee");
        prompt.calculateAIResult(50, "Generate image of bitcoin");

        vm.expectEmit(false, false, false, false);
        emit promptRequest(3847, address(this), 50,  "Generate image of bitcoin");
        (uint256 requestId,) = prompt.calculateAIResult{value: prompt.estimateFee(50)}(50, "Generate image of bitcoin");
        
        (address sender, uint256 modelId, bytes memory prompt_value, bytes memory output) = prompt.requests(requestId);
        assertEq(modelId, 50);
        assertEq(sender, address(this));
        assertEq(prompt_value, "Generate image of bitcoin");
        assertEq(string(output), "");

    }

    function test_OAOCallback() public {
        vm.expectRevert(); //TODO: add revert information
        prompt.aiOracleCallback(3847, "test", "");

        (uint256 requestId, uint256 tokenId) = prompt.calculateAIResult{value: prompt.estimateFee(50)}(50, "What is a good use case for on-chain AI?");

        vm.startPrank(OAO_PROXY);
        prompt.aiOracleCallback(requestId, "QmaD2WSUGxouY6yTnbfGoX2sezN6QktUriCczDTPbzhC9j", abi.encode(tokenId));
        vm.stopPrank();
    }

    // /// @notice Tests the behaviour of the callback after the update of the on-chain result.
    // /// @dev After the challenge period if the result is updated, the callback will be called.
    function test_CallbackAfterUpdate() public {
        (uint256 requestId, uint256 tokenId) = prompt.calculateAIResult{value: prompt.estimateFee(50)}(50, "What is a good use case for on-chain AI?");

        // first we need to execute callback
        // then we update the result
        // then callback will be called again, as the concequence of the update
        vm.startPrank(OAO_PROXY);
        prompt.aiOracleCallback(requestId, "QmaD2WSUGxouY6yTnbfGoX2sezN6QktUriCczDTPbzhC9j", abi.encode(tokenId));
        
        //we need to wait for the Opml to callback with the result
        vm.expectRevert("output not uploaded");
        prompt.updateResult(requestId);
        
        vm.stopPrank();
    }
}
