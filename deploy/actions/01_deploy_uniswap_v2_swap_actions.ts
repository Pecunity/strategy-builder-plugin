import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";

const deployUniswapV2SwapActions: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const config = deploymentConfig[chainId];

    const routerV2 = config.uniswapV2Router;

    const args = [routerV2];

    console.log("Deployment Parameter UniswapV2SwapActions:");
    console.log(`uniswap v2 router (contract): ${routerV2}`);

    const uniswapV2SwapActionsDeployment = await deploy(
      "UniswapV2SwapActions",
      {
        deterministicDeployment: deploymentSalt,
        from: deployer,
        log: true,
        waitConfirmations: 2,
        args,
      }
    );

    if (hre.network.name != "localhost") {
      await verify(uniswapV2SwapActionsDeployment.address, args);
    }
  }
};

deployUniswapV2SwapActions.tags = ["all", "uniswap-v2-swap-actions"];

export default deployUniswapV2SwapActions;
