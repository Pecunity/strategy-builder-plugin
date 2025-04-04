import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deploymentConfig, deploymentSalt, getNetworkIdFromName } from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";


const deployHealthFactorCondition: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const { deploy } = deployments;
    const { deployer } = await hre.getNamedAccounts();

    const chainId = await getNetworkIdFromName(hre.network.name);

    if (chainId) {
        const config = deploymentConfig[chainId];
        const aaveV3Pool = config.aaveV3Pool;
        const args = [aaveV3Pool];

        console.log("Deployment Parameter HealthFactorCondition:");
        console.log(`aave v3 pool (contract): ${aaveV3Pool}`);
        const healthFactorConditionDeployment = await deploy("HealthFactorCondition", {
            from: deployer,
            args: args,
            log: true,
            waitConfirmations: 2,
            deterministicDeployment: deploymentSalt
        });

        if (hre.network.name !== "hardhat") {
            await verify(healthFactorConditionDeployment.address, args);
        }
    }
}

deployHealthFactorCondition.tags = ["all", 'health-factor-condition'];

export default deployHealthFactorCondition;