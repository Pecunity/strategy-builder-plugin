import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  getNetworkIdFromName,
} from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";

const deployAaveV3PositionBalance: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);
  if (chainId) {
    const config = deploymentConfig[chainId];

    const aaveV3Pool = config.aaveV3Pool;
    const WETH = config.aaveV3WETH;
    const args = [aaveV3Pool, WETH];

    console.log("Deployment Parameter AaveV3Actions:");
    console.log(`aave v3 pool (contract): ${aaveV3Pool}`);
    console.log(`WETH (contract): ${WETH}`);
    console.log("------------------------------------");
    const aaveV3PositionBalanceDeployment = await deploy(
      "AaveV3PositionBalance",
      {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: 2,
      }
    );

    if (hre.network.name !== "hardhat") {
      await verify(aaveV3PositionBalanceDeployment.address, args);
    }
  }
};

deployAaveV3PositionBalance.tags = ["all", "aave-position-balance"];
export default deployAaveV3PositionBalance;
