import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("set-oracle", "Sets an oracle for a payment token")
  .addParam("token", "The payment token to set the oracle for")
  .addParam("oracleid", "The oracle to set")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token, oracleid: oracleId } = taskArgs;
    const { chainId } = await hre.ethers.provider.getNetwork();
    const oracle = await hre.ethers.getContractAt(
      "PriceOracle",
      getDeployedAddress(
        "StrategyBuilderCoreModule",
        "PriceOracle",
        Number(chainId)
      )
    );

    const trx = await oracle.setOracleID(token, oracleId);
    await trx.wait();
    console.log(`Oracle set for ${token}`);
  });
