import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getNetworkIdFromName } from "../../hardhat-deployment-config";
import { network } from "hardhat";
import { verify } from "../../helper-functions";

const deployCoinOrTokenBalanceCondition: DeployFunction = async (
  hre: HardhatRuntimeEnvironment
) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = await getNetworkIdFromName(hre.network.name);
  if (chainId) {
    const conditionDeployment = await deploy("CoinOrERC20BalanceCondition", {
      from: deployer,
      waitConfirmations: 1,
      log: true,
    });

    if (network.name !== "hardhat") {
      await verify(conditionDeployment.address, []);
    }
  }
};

deployCoinOrTokenBalanceCondition.tags = [
  "all",
  "coin-or-erc20-balance-condition",
];

export default deployCoinOrTokenBalanceCondition;
