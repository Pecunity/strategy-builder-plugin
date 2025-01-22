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
    octoDefiFeeManager: "0xB25a5D144626a0D488e52AE717A051a2E9997076",
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
