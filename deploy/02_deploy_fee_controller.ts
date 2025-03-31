import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../hardhat-deployment-config";
import { verify } from "../helper-functions";

const deployFeeController: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy, get } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const config = deploymentConfig[chainId].feeController;

    const maxFeeLimits = config.maxFeeLimits;
    const minFeesInUSD = config.minFeesInUSD;

    const priceOracle = (await get("PriceOracle")).address;

    const owner = config.owner

    console.log("Deployment Parameter FeeControler:");
    console.log(`priceOracle (contract): ${priceOracle}`);
    console.log(`maxFeeLimits: ${maxFeeLimits}`);
    console.log(`minFeesInUSD: ${minFeesInUSD}`);
    console.log(`owner: ${owner}`);

    const args = [priceOracle, maxFeeLimits, minFeesInUSD, owner];

    const feeControllerDeployment = await deploy("FeeController", {
      from: deployer,
      log: true,
      waitConfirmations: 2,
      deterministicDeployment: deploymentSalt,
      args,
    });

    if (hre.network.name != "localhost") {
      await verify(feeControllerDeployment.address, args);
    }
  }
};

deployFeeController.tags = ["all", "fee-controller"];

export default deployFeeController;
