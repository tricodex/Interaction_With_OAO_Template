## Introduction
This repository contains a simple template for interaction with OAO (On-chain AI Oracle). There are 3 user facing contracts: `Prompt.sol`, `PromptWithCallbackData.sol` and `PromptDifferentModels.sol`. 
- Prompt is a simple contract that can interact with OAO through *`calculateAIResult`* method.
- PromptWithCallbackData is an extension of Prompt, which passes callback data in the *`requestCallback`* method when calling OAO. This allows execution of arbitrary logic, after the OAO returns the results to the chain.
- PromptDifferentModels is an extension of Prompt, which executes different actions in the callback depending on the modelId.

## Test Guide
To execute tests run `forge test`, or `forge test -vvvv` for more info.
### Prompt.t.sol 
- test_OAOInteraction - in this test we interact with OAO by calling *`calculateAIResult`* method. This method initiates *`requestCallback`* call to the OAO system. OAO system calculates the result and sends it back to the Prompt contract along with the proof, by calling *`aiOracleCallback`* method.
- test_CallbackGasLimit - in order to return data to the Prompt.sol, OAO system needs to execute callback transaction. To do this, user needs to provide a fee as a bounty to the Prompt.sol. The gas fee required for this transaction is dependent on the gas price and the amount of gas used in the transaction. Hence, gas limit is set for each model to limit amount of gas that can be spent on a single interaction with OAO. This test checks the current gas limit of the model and sets the new one. Note that only owner of the Prompt contract can update the gas limit.
