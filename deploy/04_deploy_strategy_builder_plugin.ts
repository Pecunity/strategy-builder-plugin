import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentSalt,
  getNetworkIdFromName,
} from "../hardhat-deployment-config";
import { verify } from "../helper-functions";

const deployStrategyBuilderPlugin: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy, get } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const feeController = (await get("FeeController")).address;
    const feeHandler = (await get("FeeHandler")).address;

    console.log("Deployment Parameter StrategyBuilderPlugin:");
    console.log(`feeController (contract): ${feeController}`);
    console.log(`feeHandler (contract): ${feeHandler}`);

    const args = [feeController, feeHandler];
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
  }
};

deployStrategyBuilderPlugin.tags = ["all", "strategy-builder"];

export default deployStrategyBuilderPlugin;
