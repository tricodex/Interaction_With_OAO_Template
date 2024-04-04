// SampleContract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IAIOracle.sol";
import "./AIOracleCallbackReceiver.sol";

contract PromptWithCallbackData is AIOracleCallbackReceiver {

    event promptsUpdated(
        uint256 requestId,
        uint256 modelId,
        string input,
        string output,
        bytes callbackData
    );

    event promptRequest(
        uint256 requestId,
        address sender, 
        uint256 modelId,
        string prompt
    );

    struct AIOracleRequest {
        address sender;
        uint256 modelId;
        bytes input;
        bytes output;
    }

    address owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // requestId => AIOracleRequest
    mapping(uint256 => AIOracleRequest) public requests;

    // modelId => callback gasLimit
    mapping(uint256 => uint64) public callbackGasLimit;

    /// @notice Initialize the contract, binding it to a specified AIOracle.
    constructor(IAIOracle _aiOracle) AIOracleCallbackReceiver(_aiOracle) {
        owner = msg.sender;
        callbackGasLimit[50] = 500_000; // SD 500k
        callbackGasLimit[11] = 5_000_000; // llama
        callbackGasLimit[9] = 5_000_000; // grok
    }

    function setCallbackGasLimit(uint256 modelId, uint64 gasLimit) external onlyOwner {
        callbackGasLimit[modelId] = gasLimit;
    }

    // uint256: modelID => (string: prompt => string: output)
    mapping(uint256 => mapping(string => string)) public prompts;

    function getAIResult(uint256 modelId, string calldata prompt) external view returns (string memory) {
        return prompts[modelId][prompt];
    }

    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external override onlyAIOracleCallback() {
        AIOracleRequest storage request = requests[requestId];
        require(request.sender != address(0), "request not exists");
        request.output = output;
        prompts[request.modelId][string(request.input)] = string(output);

        uint256 callbackInt = abi.decode(callbackData, (uint256));
        require(callbackInt != 0, "Returned Int can't be 0");

        emit promptsUpdated(requestId, request.modelId, string(request.input), string(output), callbackData);
    }

    function estimateFee(uint256 modelId) public view returns (uint256) {
        return aiOracle.estimateFee(modelId, callbackGasLimit[modelId]);
    }

    function calculateAIResult(uint256 modelId, string calldata prompt, uint256 callbackInt) payable external {
        bytes memory input = bytes(prompt);
        uint256 requestId = aiOracle.requestCallback{value: msg.value}(
            modelId, input, address(this), callbackGasLimit[modelId], abi.encode(callbackInt)
        );
        AIOracleRequest storage request = requests[requestId];
        request.input = input;
        request.sender = msg.sender;
        request.modelId = modelId;
        emit promptRequest(requestId, msg.sender, modelId, prompt);
    }
}