// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {TestPrompt} from "./TestPrompt.sol";

interface IAIOracle {
    /// @notice Event emitted upon receiving a callback request through requestCallback.
    event AICallbackRequest(
        address indexed account,
        uint256 indexed requestId,
        uint256 modelId,
        bytes input,
        address callbackContract,
        uint64 gasLimit,
        bytes callbackData
    );

    /// @notice Event emitted when the result is uploaded or update.
    event AICallbackResult(
        address indexed account,
        uint256 indexed requestId,
        address invoker,
        bytes output
    );

    /**
     * initiate a request in OAO
     * @param modelId ID for AI model
     * @param input input for AI model
     * @param callbackContract address of callback contract
     * @param gasLimit gas limitation of calling the callback function
     * @param callbackData optional, user-defined data, will send back to the callback function
     * @return requestID
     */
    function requestCallback(
        uint256 modelId,
        bytes memory input,
        address callbackContract,
        uint64 gasLimit,
        bytes memory callbackData
    ) external payable returns (uint256);

    function estimateFee(uint256 modelId, uint256 gasLimit) external view returns (uint256);

    function isFinalized(uint256 requestId) external view returns (bool);
    
    function updateResult(uint256 requestId) external;
}

contract MockOAO is IAIOracle {
    uint256 lastRequest;
    mapping(uint256 => AICallbackRequestData) public requests;
    bytes4 constant public callbackFunctionSelector = 0xb0347814;
    uint256 public gasPrice;

    struct AICallbackRequestData{
        address account;
        uint256 requestId;
        uint256 modelId;
        bytes input;
        address callbackContract;
        uint64 gasLimit;
        bytes callbackData;
        bytes output;
    }

    ///@notice mock function that emulates OAO computation and calls back into the Prompt
    function requestCallback(
        uint256 modelId,
        bytes memory input,
        address callbackContract,
        uint64 gasLimit,
        bytes memory callbackData
    ) external payable returns (uint256) {
        AICallbackRequestData storage request = requests[++lastRequest];
        request.account = msg.sender;
        request.requestId = lastRequest;
        request.modelId = modelId;
        request.input = input;
        request.callbackContract = callbackContract;
        request.gasLimit = gasLimit;
        request.callbackData = callbackData;

        emit AICallbackRequest(request.account, request.requestId, modelId, input, callbackContract, gasLimit, callbackData);

        return request.requestId;
    }

    function invokeCallback(uint256 requestId, bytes calldata output) external {
        // read request of requestId
        AICallbackRequestData storage request = requests[requestId];
        
        // others can challenge if the result is incorrect!
        request.output = output;

        // invoke callback
        if(request.callbackContract != address(0)) {
            bytes memory payload = abi.encodeWithSelector(callbackFunctionSelector, request.requestId, output, request.callbackData);
            (bool success, bytes memory data) = request.callbackContract.call{gas: request.gasLimit}(payload);
            require(success, "failed to call selector");
            if (!success) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
        }

        emit AICallbackResult(request.account, requestId, msg.sender, output);

        gasPrice = tx.gasprice;
    }

    // call this function if the opml result is challenged and updated!
    // anyone can call it!
    function updateResult(uint256 requestId) external {
        // read request of requestId
        AICallbackRequestData storage request = requests[requestId];

        // get Latest output of request
        bytes memory output = request.output;
        require(output.length > 0, "output not uploaded");

        // invoke callback
        if(request.callbackContract != address(0)) {
            bytes memory payload = abi.encodeWithSelector(callbackFunctionSelector, request.requestId, output, request.callbackData);
            (bool success, bytes memory data) = request.callbackContract.call{gas: request.gasLimit}(payload);
            require(success, "failed to call selector");
            if (!success) {
                assembly {
                    revert(add(data, 32), mload(data))
                }
            }
        }

        emit AICallbackResult(request.account, requestId, msg.sender, output);
    }

    function isFinalized(uint256 requestId) external view returns (bool) {
        return true;
    }

    function estimateFee(uint256 modelId, uint256 gasLimit) public view returns (uint256) {
        return 3 + gasPrice * gasLimit;
    }
}