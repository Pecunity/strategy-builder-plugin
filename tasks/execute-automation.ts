import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

interface ExecuteAutomationTaskArgs {
  automationid: number;
  wallet: string;
}

task("execute-automation", "Executes an automation")
  .addParam("automationid", "Automation ID")
  .addParam("wallet", "wallet address")
  .setAction(
    async (
      taskArgs: ExecuteAutomationTaskArgs,
      hre: HardhatRuntimeEnvironment
    ) => {
      const { automationid: automationId, wallet } = taskArgs;

      const { chainId } = await hre.ethers.provider.getNetwork();

      const strategyBuilderPluginAddress = getDeployedAddress(
        "StrategyBuilderCoreModule",
        "StrategyBuilderModule",
        Number(chainId)
      );

      const strategyBuilderPlugin = await hre.ethers.getContractAt(
        "StrategyBuilderModule",
        strategyBuilderPluginAddress
      );
      const signer = (await hre.ethers.getSigners())[0];
      const trx = await strategyBuilderPlugin.executeAutomation(
        automationId,
        wallet,
        signer.address
      );

      await trx.wait();

      console.log(`Executed automation ${automationId} from wallet ${wallet}`);
    }
  );
