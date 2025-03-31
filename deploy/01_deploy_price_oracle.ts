import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../hardhat-deployment-config";
import { network } from "hardhat";
import { verify } from "../helper-functions";

const deployPriceOracle: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const config = deploymentConfig[chainId].priceOracle;

    const pythOracle = config.pythOracle;
    const owner = config.owner;

    console.log("Deployment Parameter PriceOracle:");
    console.log(`pythOracle (contract): ${pythOracle}`);
    console.log(`owner (address): ${owner}`)

    //arguments
    const args = [config.pythOracle, owner];

    const priceOracleDeployment = await deploy("PriceOracle", {
      from: deployer,
      log: true,
      waitConfirmations: 2,
      deterministicDeployment: deploymentSalt,
      args,
    });

    if (network.name != "localhost") {
      await verify(priceOracleDeployment.address, args);
    }
  }
};

deployPriceOracle.tags = ["all", "price-oracle"];

export default deployPriceOracle;
