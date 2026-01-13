import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("deposit-for-account", "Deposits tokens for an account ")
  .addParam("token", "Token address")
  .addParam("account", "Account address")
  .addParam("amount", "Amount to deposit")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token, account, amount } = taskArgs;
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

    const tokenContract = await hre.ethers.getContractAt("ERC20", token);
    console.log(`approve token for feeHandler`);
    const approveTrx = await tokenContract.approve(
      feeHandlerAddress,
      hre.ethers.parseUnits(amount, 18)
    );

    await approveTrx.wait();

    console.log(`deposit token for account`);

    const trx = await feeHandler.depositTokenFor(
      account,
      token,
      hre.ethers.parseUnits(amount, 18)
    );

    await trx.wait();

    console.log(`Deposited ${amount} ${token} for account ${account}`);
  });
