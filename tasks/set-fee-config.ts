import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("set-fee-config", "Set the fee config")
  .addParam("selector", "The function selector to set")
  .addParam("type", "The fee type to set (0: deposit, 1: withdraw, 2: reward)")
  .addParam("percentage", "The percentage to set (e.g. 0.10 for 10%)")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const DIVISOR = 10000;

    const { type, percentage, selector } = taskArgs;

    const { chainId } = await hre.ethers.provider.getNetwork();

    const feeControllerAddress = getDeployedAddress(
      "StrategyBuilderCoreModule",
      "FeeController",
      Number(chainId),
    );

    const feeControllerContract = await hre.ethers.getContractAt(
      "FeeController",
      feeControllerAddress,
    );

    const parsedFee = Number(percentage) * DIVISOR;

    console.log(
      `Setting fee config for ${selector} to ${percentage}% (type: ${type})`,
    );

    const trx = await feeControllerContract.setFunctionFeeConfig(
      selector,
      type,
      parsedFee,
    );
    await trx.wait();
    console.log(`Successfully set fee config for ${selector}`);
  });
