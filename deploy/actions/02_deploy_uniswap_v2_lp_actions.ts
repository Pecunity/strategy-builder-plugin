import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deploymentConfig, deploymentSalt, getNetworkIdFromName } from "../../hardhat-deployment-config";
import { verify } from "../../helper-functions";


const deployUniswapV2LPActions: DeployFunction = async (
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

        const uniswapV2LPActionsDeployment = await deploy("UniswapV2LPActions", {
            from: deployer,
            args: args,
            log: true,
            waitConfirmations: 2,
            deterministicDeployment: deploymentSalt
        });

        if (hre.network.name !== "hardhat") {

            await verify(uniswapV2LPActionsDeployment.address, args);
        }
    }
}

deployUniswapV2LPActions.tags = ["all", "uniswap-V2-lp-actions"];

export default deployUniswapV2LPActions;