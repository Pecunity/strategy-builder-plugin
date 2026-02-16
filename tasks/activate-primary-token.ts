import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("activate-primary-token")
  .addParam("token", "The primary token address")
  .addParam("b", "The token burn amount in percentage")
  .addParam("pd", "The primary token discount in percentage")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token, b: tokenBurn, pd: primaryTokenDiscount } = taskArgs;

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

    const percentageDivisor = await feeHandler.PERCENTAGE_DIVISOR();

    const parsedTokenBurn =
      (Number(tokenBurn) / 100) * Number(percentageDivisor);

    const parsedPrimaryDiscount =
      (Number(primaryTokenDiscount) / 100) * Number(percentageDivisor);

    const burnerAddress = getDeployedAddress(
      "TokenBurnerModule",
      "TokenBurner",
      Number(chainId),
    );

    console.log(`burn contract address: ${burnerAddress}`);

    console.log(
      `parsed parameters. token burn: ${parsedTokenBurn}, primary discount: ${parsedPrimaryDiscount}`,
    );

    const trx = await feeHandler.activatePrimaryToken(
      token,
      burnerAddress,
      parsedPrimaryDiscount,
      parsedTokenBurn,
      parsedTokenBurn,
    );

    await trx.wait();

    console.log(`successfull activate primary token!`);
  });
