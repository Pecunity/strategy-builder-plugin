import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("set-custom-oracle", "Sets a custom oracle for a payment token")
  .addParam("token", "The payment token to set the oracle for")
  .addParam("oracle", "The oracle address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token, oracle } = taskArgs;
    const { chainId } = await hre.ethers.provider.getNetwork();
    const priceOracleContract = await hre.ethers.getContractAt(
      "PriceOracle",
      getDeployedAddress(
        "StrategyBuilderCoreModule",
        "PriceOracle",
        Number(chainId),
      ),
    );

    const trx = await priceOracleContract.setCustomOracle(token, oracle);
    await trx.wait();
    console.log(`Custom Oracle set for ${token}`);
  });
