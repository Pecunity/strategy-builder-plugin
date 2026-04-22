import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("mock-vault-set-owner", "Sets the owner on the MockVault contract")
  .addParam("owner", "The new owner address to set")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { owner } = taskArgs;
    const { chainId } = await hre.ethers.provider.getNetwork();

    const mockVaultAddress = getDeployedAddress(
      "MockVaultModule",
      "MockVault",
      Number(chainId),
    );

    const mockVault = await hre.ethers.getContractAt(
      "MockVault",
      mockVaultAddress,
    );

    const trx = await mockVault.setOwner(owner);
    await trx.wait();

    console.log(`MockVault owner set to ${owner}`);
  });
