import { task } from "hardhat/config";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("change-fees", "Change the fees of the strategy builder")
  .addParam("fees")
  .setAction(async (taskArgs, hre) => {
    const { fees } = taskArgs;

    const enable = fees === "true";

    const { chainId } = await hre.ethers.provider.getNetwork();
    const strategyBuilder = await hre.ethers.getContractAt(
      "StrategyBuilderModule",
      getDeployedAddress(
        "StrategyBuilderCoreModule",
        "StrategyBuilderModule",
        Number(chainId)
      )
    );

    const trx = enable
      ? await strategyBuilder.enableFees()
      : await strategyBuilder.disableFees();

    await trx.wait();

    console.log(`Successfull ${enable ? "enable" : "disable"} fees`);
  });
