import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("allow-payment-token", "Allow a payment token")
  .addParam("token", "The payment token to allow")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token } = taskArgs;

    const { chainId } = await hre.ethers.provider.getNetwork();

    const feeHandlerAddress = getDeployedAddress(
      "StrategyBuilderCoreModule",
      "FeeHandler",
      Number(chainId)
    );
    const feeHandler = await hre.ethers.getContractAt(
      "FeeHandler",
      feeHandlerAddress
    );
    const trx = await feeHandler.updateTokenAllowance(token, true);
    await trx.wait();
    console.log(`Token ${token} allowed`);
  });
