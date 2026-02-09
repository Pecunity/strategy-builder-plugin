import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("set-token-getter", "Set the token getter contract address")
  .addParam("tokengetter", "The token getter contract address")
  .addParam("selector", "The function selector to set")
  .addParam("contract", "The contract address to set")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { selector, contract, tokengetter: tokenGetter } = taskArgs;

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

    const trx = await feeControllerContract.setTokenGetter(
      selector,
      tokenGetter,
      contract,
    );
    await trx.wait();
    console.log(`Successfully set token getter for ${selector}`);
    console.log(`transaction hash: ${trx.hash}`);
  });
