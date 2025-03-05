import { parseEther } from "ethers";

export interface IDeploymentConfig {
  [key: number]: any;
}

export const deploymentSalt =
  "0x90d8084deab30c2a37c45e8d47f49f2f7965183cb6990a98943ef94940681de3";

export const deploymentConfig: IDeploymentConfig = {
  421614: {
    name: "arbitrumSepolia",
    uniswapV2Router: "0x2bC5d014a1C1f9Fd76618304Cf3121199e438bDd",
    poolAddressProviderAaveV3: "0xB25a5D144626a0D488e52AE717A051a2E9997076",
    priceOracle: {
      pythOracle: "0x4374e5a8b9C22271E9EB878A2AA31DE97DF15DAF", //https://docs.pyth.network/price-feeds/contract-addresses/evm
    },
    feeController: {
      maxFeeLimits: [500, 1000, 200],
      minFeesInUSD: [parseEther("1.0"), parseEther("2.0"), parseEther("0.5")],
    },
    feeHandler: {
      vault: "0x36375828fd821935cFf3E8AB6322cAb54BBfaDeC",
      beneficiaryPercentage: 1000, //10%
      creatorPercentage: 500, //5%
      vaultPercentage: 8500, //85%
    },
  },
};

export const defaultConfig = {
  octoDefiFeeManager: "0xB25a5D144626a0D488e52AE717A051a2E9997076",
};

export const getNetworkIdFromName = async (networkIdName: string) => {
  for (const id in deploymentConfig) {
    if (deploymentConfig[id]["name"] === networkIdName) {
      return Number(id);
    }
  }
  return null;
};
