# StrategyBuilderPlugin - ERC6900 Standard

![Octo DeFi Logo](./assets/octo-defi-logo.png)

## Overview

The **StrategyBuilderPlugin** is a modular smart contract built on the **ERC6900 standard**, designed to automate and execute **advanced DeFi strategies** seamlessly. This plugin integrates with modular smart accounts, allowing users to create, manage, and automate complex financial strategies such as **vault management, borrowing, leveraged yield farming, and more**.

## Features

✅ **DeFi Strategy Automation** – Users can define and execute automated strategies involving lending, borrowing, staking, and farming.  
✅ **Modular & Extensible** – Built within the ERC6900 ecosystem, enabling compatibility with other modular account plugins.  
✅ **Smart Execution & Conditions** – Allows strategies to execute based on predefined conditions, optimizing yield and efficiency.  
✅ **Fee Management Integration** – Implements **IFeeController** and **IFeeHandler** to ensure seamless fee handling for automated transactions.  
✅ **Security & Permissions** – Utilizes **strategy validation** to ensure only authorized actions are executed within a user’s smart account.

## How It Works

1. **Strategy Creation** – Users define custom strategies that include multiple **DeFi actions** (e.g., borrowing, staking, swapping).
2. **Automated Execution** – The plugin triggers actions based on conditions (e.g., interest rate thresholds, collateral ratios).
3. **Fee Handling** – Ensures fair and transparent fee structures using external controllers and handlers.
4. **Smart Account Integration** – Seamlessly integrates with modular smart accounts, leveraging ERC6900’s flexible permissioning system.

## Use Cases

- **Automated Yield Farming** – Deploy capital across multiple DeFi protocols for optimal returns.
- **Vault Management** – Automatically rebalance or reinvest assets in DeFi vaults.
- **Leverage Strategies** – Execute leveraged borrowing and farming with automated risk management.
- **Automated Liquidation Protection** – Prevent unnecessary liquidations by setting up stop-loss mechanisms.

## Why StrategyBuilderPlugin?

By leveraging the **ERC6900 modular account standard**, this plugin enhances DeFi automation, making complex financial strategies **accessible, secure, and highly efficient** for both institutional and individual users.

---

## Installation

After cloning the repository, install the dependencies with:

```bash
npm install
```

Make sure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed before proceeding.

Then build the contracts with:

```bash
forge build
```

---

Would you like me to assemble the full README now with all sections (Intro, Requirements, Environment, Installation, Usage)?

## Environment Setup

Before working with this project, you need to set the required environment variables.

Use the following Hardhat commands to store your secrets locally:

```bash
npx hardhat vars set ALCHEMY_API_KEY
npx hardhat vars set PRIVATE_KEY
npx hardhat vars set ARBISCAN_API_KEY
```

These variables are required for deployments:

| Variable           | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| `ALCHEMY_API_KEY`  | API key from Alchemy for your RPC connection.                      |
| `PRIVATE_KEY`      | Private key of the deployer wallet. Never share this key publicly. |
| `ARBISCAN_API_KEY` | API key from arbiscan for contract verification.                   |

> These variables will be stored securely on your local machine and automatically loaded when running Hardhat tasks.

---

## Core Contracts

There are four core smart contracts that make up the heart of the system:

- **PriceOracle**  
  Fetches real-time price data from the Pyth network.

- **FeeController**  
  Manages the fee configuration for each individual function selector used in strategy execution.

- **FeeHandler**  
  Distributes the total collected fee among recipients based on predefined percentages at the end of strategy execution.

- **StrategyBuilderPlugin**  
  An ERC-6900 compatible plugin contract that provides the main functionality of the strategy builder—allowing you to create, execute, and manage strategies.

> 🔎 For a detailed description of the **StrategyBuilder**, check out the official documentation: [https://docs.octodefi.com](https://docs.octodefi.com)

### Source Code

You can find the source code for each core contract below:

| Contract              | Description                            | Source Code Link                                                   |
| --------------------- | -------------------------------------- | ------------------------------------------------------------------ |
| PriceOracle           | Fetches price data from Pyth           | [PriceOracle.sol](./contracts/PriceOracle.sol)                     |
| FeeController         | Manages function-specific fees         | [FeeController.sol](./contracts/FeeController.sol)                 |
| FeeHandler            | Handles fee distribution               | [FeeHandler.sol](./contracts/FeeHandler.sol)                       |
| StrategyBuilderPlugin | Strategy builder core logic (ERC-6900) | [StrategyBuilderPlugin.sol](./contracts/StrategyBuilderPlugin.sol) |

---

### Example Strategy Execution Flow

When an automation service (or user) triggers the execution of a strategy, the following steps take place within the core contracts:

1. **Pre-Execution Check via ConditionContract**  
   The `StrategyBuilderPlugin` first checks the `ConditionContract` defined in the strategy's `ActionStruct`. This contract verifies whether the conditions for execution are currently met (e.g., price thresholds, time-based triggers, on-chain state, etc.).

2. **Step-by-Step Execution**  
   If the condition check passes, the `StrategyBuilderPlugin` begins executing the defined steps of the strategy one by one.

   After entering a step, the plugin checks whether the step has an associated condition. If it does:

   - The plugin calls the `ConditionContract` to evaluate the condition.
   - If the condition result is `true (1)`, the plugin executes all actions defined in that step and then jumps to the **next step defined for a true result**.
   - If the condition result is `false (0)`, the plugin **skips execution** of the actions in that step and moves to the **next step defined for a false result**.

3. **Fee Preparation for Each Action**  
   Before executing each individual action, the plugin interacts with the `FeeController` to:

   - Retrieve the observation token relevant to that action.
   - Record the token balance before execution.

   After the action is executed, the plugin checks the balance again to determine the amount of token affected by that action. Using this delta, it calls the `FeeController` to calculate the specific fee for that action.

4. **Final Fee Distribution**  
   Once all actions have been executed and all fees have been calculated, the `StrategyBuilderPlugin` calls the `FeeHandler` contract. The `FeeHandler` is responsible for distributing the total collected fee to the configured recipients, based on their assigned percentage shares.

---

## Getting Started

After installing Foundry, follow these steps to set up and deploy:

```bash

# Build contracts with Foundry and Hardhat
npm run compile

# Run Foundry tests
forge test

# Check code coverage
npm run coverage

# Deploy core contract
NETWORK=<network-name> npm run deploy:core

# Verify the contracts
CHAIN_ID=<chain-id> npm run verify:core
```

Replace `<network-name>` with your desired network (e.g. `localhost`, `arbitrumSepolia`, `mainnet`).
Eplace `<chain-id>` with the chain ID of your network.

---

## Notes

- Contract deployments are managed using [Hardhat Ignition](https://hardhat.org/hardhat-ignition).
- Foundry is used for building and testing smart contracts.

---

🔗 **Author:** 3Blocks  
📜 **License:** MIT  
🚀 **Version:** 1.0.0

## Foundry Documentation

https://book.getfoundry.sh/
