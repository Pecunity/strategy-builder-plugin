import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deploymentSalt } from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";

const deployTimeCondition: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deploy } = hre.deployments;

  const { deployer } = await hre.getNamedAccounts();

  const timeConditionDeployment = await deploy("TimeCondition", {
    from: deployer,
    deterministicDeployment: deploymentSalt,
    log: true,
    waitConfirmations: 2,
  });

  if (hre.network.name != "localhost") {
    await verify(timeConditionDeployment.address, []);
  }
};

deployTimeCondition.tags = ["all", "time-condition"];

export default deployTimeCondition;
