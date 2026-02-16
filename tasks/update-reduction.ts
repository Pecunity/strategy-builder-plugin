import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("update-reduction")
  .addParam("addr", "The new reduction address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { addr } = taskArgs;

    const { chainId } = await hre.ethers.provider.getNetwork();

    const feeHandlerAddress = getDeployedAddress(
      "StrategyBuilderCoreModule",
      "FeeHandler",
      Number(chainId),
    );
    const feeHandler = await hre.ethers.getContractAt(
      "FeeHandler",
      feeHandlerAddress,
    );

    const trx = await feeHandler.updateReduction(addr);
    await trx.wait();
    console.log(`Successfully updated reduction to ${addr}`);
  });
