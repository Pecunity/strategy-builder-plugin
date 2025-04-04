import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";

const deployAaveV3Actions: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deployments } = hre;
  const { deploy } = deployments;
  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const config = deploymentConfig[chainId];
    const aaveV3Pool = config.aaveV3Pool;
    const WETH = config.aaveV3WETH;
    const oracle = config.aaveV3Oracle;
    const args = [aaveV3Pool, WETH, oracle];
    console.log("Deployment Parameter AaveV3Actions:");
    console.log(`aave v3 pool (contract): ${aaveV3Pool}`);
    console.log(`WETH (contract): ${WETH}`);
    console.log(`oracle (contract): ${oracle}`);
    console.log("------------------------------------");
    const aaveV3ActionsDeployment = await deploy("AaveV3Actions", {
      from: deployer,
      args: args,
      log: true,
      waitConfirmations: 2,
      deterministicDeployment: deploymentSalt,
    });

    if (hre.network.name !== "hardhat") {
      await verify(aaveV3ActionsDeployment.address, args);
    }
  }
};

deployAaveV3Actions.tags = ["all", "aave-V3-actions"];

export default deployAaveV3Actions;
