// SampleContract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IAIOracle.sol";
import "./AIOracleCallbackReceiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PromptWithCallbackData is AIOracleCallbackReceiver, ERC721 {

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

    struct TokenMetadata {
        string image; //CID of the image on ipfs
        string prompt;
    }

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    uint256 private nextTokenId;

    // tokenId => metamdata
    mapping(uint256 => TokenMetadata) public metadataStorage;

    // requestId => AIOracleRequest
    mapping(uint256 => AIOracleRequest) public requests;

    // modelId => callback gasLimit
    mapping(uint256 => uint64) public callbackGasLimit;

    /// @notice Initialize the contract, binding it to a specified AIOracle.
    constructor(IAIOracle _aiOracle) AIOracleCallbackReceiver(_aiOracle) ERC721("On-chain AI Oracle", "OAO"){
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
        
        uint256 tokenId = abi.decode(callbackData, (uint256));
        metadataStorage[tokenId].image = string(output);

        emit promptsUpdated(requestId, request.modelId, string(request.input), string(output), callbackData);
    }

    function estimateFee(uint256 modelId) public view returns (uint256) {
        return aiOracle.estimateFee(modelId, callbackGasLimit[modelId]);
    }

    /// @notice minting a token without metadata
    /// @dev called when ineracting with OAO
    function mint() internal {
        nextTokenId++;
        _safeMint(msg.sender, nextTokenId);
    }

    function updateResult(uint256 requestId) external {
        aiOracle.updateResult(requestId);
    }

    function calculateAIResult(uint256 modelId, string calldata prompt) payable external returns (uint256, uint256) {
        bytes memory input = bytes(prompt);
        mint();

        metadataStorage[nextTokenId].prompt = prompt;

        uint256 requestId = aiOracle.requestCallback{value: msg.value}(
            modelId, input, address(this), callbackGasLimit[modelId], abi.encode(nextTokenId)
        );
        
        AIOracleRequest storage request = requests[requestId];
        request.input = input;
        request.sender = msg.sender;
        request.modelId = modelId;

        emit promptRequest(requestId, msg.sender, modelId, prompt);
        return (requestId, nextTokenId);
    }
}