// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "OAO/contracts/interfaces/IAIOracle.sol";
import "./AIOracleCallbackReceiverPayable.sol";

/// @notice Contract that requests double inference from OAO. 
/// @dev First inference is initiated through calculateAIResult method, the second one is requested from the callback.
contract PromptNestedInference is AIOracleCallbackReceiverPayable {
    
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
        uint256 model1Id,
        uint256 model2Id,
        string prompt
    );

    struct AIOracleRequest {
        address sender;
        uint256 modelId;
        bytes input;
        bytes output;
    }

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @dev requestId => AIOracleRequest
    mapping(uint256 => AIOracleRequest) public requests;

    /// @dev modelId => callback gasLimit
    mapping(uint256 => uint64) public callbackGasLimit;

    /// @notice Initialize the contract, binding it to a specified AIOracle.
    constructor(IAIOracle _aiOracle) AIOracleCallbackReceiverPayable(_aiOracle) {
        owner = msg.sender;
        callbackGasLimit[50] = 500_000; // Stable Diffusion
        callbackGasLimit[11] = 5_000_000; // Llama
        callbackGasLimit[9] = 5_000_000; // Grok
    }

    /// @notice sets the callback gas limit for a model
    /// @dev only only can set the gas limit
    function setCallbackGasLimit(uint256 modelId, uint64 gasLimit) external onlyOwner {
        callbackGasLimit[modelId] = gasLimit;
    }

    /// @dev uint256: modelID => (string: prompt => string: output)
    mapping(uint256 => mapping(string => string)) public prompts;

    /// @notice returns the output for the specified model and prompt
    function getAIResult(uint256 modelId, string calldata prompt) external view returns (string memory) {
        return prompts[modelId][prompt];
    }

    /// @notice OAO executes this method after it finishes with computation
    /// @param requestId id of the request  
    /// @param output result of the OAO computation
    /// @param callbackData Callback data is the modelId and the prompt for AI request.
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external payable override onlyAIOracleCallback() {
        AIOracleRequest storage request = requests[requestId];
        require(request.sender != address(0), "request does not exist");
        request.output = output;
        prompts[request.modelId][string(request.input)] = string(output);

        //if callbackData is not empty decode it and call another inference
        if(callbackData.length != 0){
            (uint256 model2Id, string memory prompt2) = abi.decode(callbackData, (uint256, string));
            aiOracle.requestCallback{value: msg.value}(
                model2Id, bytes(prompt2), address(this), callbackGasLimit[model2Id], ""
            );
        }

        emit promptsUpdated(requestId, request.modelId, string(request.input), string(output), callbackData);
    }

    /// @notice estimating fee that is spent by OAO
    function estimateFee(uint256 modelId) public view returns (uint256) {
        return aiOracle.estimateFee(modelId, callbackGasLimit[modelId]);
    }

    /// @notice main point of interaction with OAO
    /// @dev modelId and prompt for second inference are passed as the callback data.
    function calculateAIResult(uint256 model1Id, uint256 model2Id, string calldata model1Prompt) payable external returns (uint256) {
        bytes memory input = bytes(model1Prompt);
        uint256 requestId = aiOracle.requestCallback{value: msg.value}(
            model1Id, input, address(this), callbackGasLimit[model1Id], abi.encode(model2Id, model1Prompt)
        );
        AIOracleRequest storage request = requests[requestId];
        request.input = input;
        request.sender = msg.sender;
        request.modelId = model1Id;
        emit promptRequest(requestId, msg.sender, model1Id, model2Id, model1Prompt);
        return requestId;
    }
}