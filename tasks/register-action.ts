import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

interface RegisterActionTaskArgs {
  actionaddress: string;
  register: boolean;
}

task("register-action", "Register an action to the strategy builder")
  .addParam("actionaddress")
  .addParam("register")
  .setAction(
    async (
      taskArgs: RegisterActionTaskArgs,
      hre: HardhatRuntimeEnvironment
    ) => {
      const { actionaddress: actionAddress, register } = taskArgs;

      const { chainId } = await hre.ethers.provider.getNetwork();

      const actionRegistryAddress = getDeployedAddress(
        "StrategyBuilderCoreModule",
        "ActionRegistry",
        Number(chainId)
      );

      const registryContract = await hre.ethers.getContractAt(
        "ActionRegistry",
        actionRegistryAddress
      );

      const trx = register
        ? await registryContract.allowAction(actionAddress)
        : await registryContract.revokeAction(actionAddress);

      await trx.wait();

      console.log(
        `Successfull ${register ? "allow" : "revoke"} action ${actionAddress}`
      );
    }
  );
