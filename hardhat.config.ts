import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-deploy";
import * as dotenv from "dotenv";
import { NetworkUserConfig } from "hardhat/types";
dotenv.config();

import "./tasks";

/** @type import('hardhat/config').HardhatUserConfig */
const deployerPrivateKey =
  process.env.PRIVATE_KEY ??
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

const infuraUrl = (name: string): string =>
  `https://${name}.infura.io/v3/${process.env.INFURA_ID}`;

function getNetwork(url: string): NetworkUserConfig {
  return {
    url,
    accounts: [deployerPrivateKey],
  };
}

function getInfuraNetwork(name: string): NetworkUserConfig {
  return getNetwork(infuraUrl(name));
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24", // Your Solidity version
    settings: {
      optimizer: {
        enabled: true, // Enable optimization
        runs: 200, // Set the number of optimization runs (200 is a common balance)
      },
    },
  },
  networks: {
    arbitrumSepolia: getInfuraNetwork("arbitrum-sepolia"),
  },
  namedAccounts: {
    deployer: {
      // By default, it will take the first Hardhat account as the deployer
      default: 0,
    },
    deterministicDeployer: {
      default: 0,
    },
  },
  etherscan: {
    apiKey: {
      arbitrumSepolia: process.env.ARBISCAN_API_KEY ?? "",
    },
  },
};

export default config;
