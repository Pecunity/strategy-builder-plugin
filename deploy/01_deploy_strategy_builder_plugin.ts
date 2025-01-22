import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  defaultConfig,
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../hardhat-deployment-config";
import { verify } from "../helper-functions";

const deployStrategyBuilderPlugin: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  let _deploymentConfig;
  if (chainId) {
    _deploymentConfig = deploymentConfig[chainId];
  } else {
    _deploymentConfig = defaultConfig;
  }

  const feeManager = _deploymentConfig.octoDefiFeeManager;
  console.log(feeManager);
  const args = [feeManager];
  const deployment = await deploy("StrategyBuilderPlugin", {
    from: deployer,
    log: true,
    waitConfirmations: 1,
    deterministicDeployment: deploymentSalt,
    args: args,
  });

  if (hre.network.name != "localhost") {
    await verify(deployment.address, args);
  }
};

deployStrategyBuilderPlugin.tags = ["all", "strategy-builder"];

export default deployStrategyBuilderPlugin;
