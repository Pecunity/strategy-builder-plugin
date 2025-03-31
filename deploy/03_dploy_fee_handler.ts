import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  deploymentConfig,
  deploymentSalt,
  getNetworkIdFromName,
} from "../hardhat-deployment-config";
import { verify } from "../helper-functions";

const deployFeeHandler: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);

  if (chainId) {
    const config = deploymentConfig[chainId].feeHandler;

    const vault = config.vault;
    const beneficiaryPercentage = config.beneficiaryPercentage;
    const creatorPercentage = config.creatorPercentage;
    const vaultPercentage = config.vaultPercentage;
    const owner = config.owner

    console.log("Deployment Parameter FeeHandler:");
    console.log(`vault: ${vault}`);
    console.log(`beneficiaryPercentage: ${beneficiaryPercentage}`);
    console.log(`creatorPercentage: ${creatorPercentage}`);
    console.log(`vaultPercentage: ${vaultPercentage}`);
    console.log(`owner: ${owner}`);

    const args = [
      vault,
      beneficiaryPercentage,
      creatorPercentage,
      vaultPercentage,
      owner
    ];

    const feeHandlerDeployment = await deploy("FeeHandler", {
      from: deployer,
      waitConfirmations: 2,
      log: true,
      deterministicDeployment: deploymentSalt,
      args,
    });

    if (hre.network.name != "localhost") {
      await verify(feeHandlerDeployment.address, args);
    }
  }
};

deployFeeHandler.tags = ["all", "fee-handler"];

export default deployFeeHandler;
