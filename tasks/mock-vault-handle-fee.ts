import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getDeployedAddress } from "../utils/get-deployed-address";

task("mock-vault-handle-fee", "Calls handleFeeWithVault via the MockVault")
  .addParam("token", "The ERC20 token address used for the fee")
  .addParam("amount", "The fee amount (in ether units, e.g. 1.5)")
  .addParam("beneficiary", "The beneficiary address")
  .addOptionalParam("creator", "The creator address (defaults to zero address)")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token, amount, beneficiary } = taskArgs;
    const creator = taskArgs.creator ?? hre.ethers.ZeroAddress;

    const { chainId } = await hre.ethers.provider.getNetwork();

    const mockVaultAddress = getDeployedAddress(
      "MockVaultModule",
      "MockVault",
      Number(chainId),
    );

    const feeHandlerAddress = "0x6C78713C0a6054ff66CFc33A651e9eDCA774Ce82";

    const parsedAmount = hre.ethers.parseEther(amount);

    // const tokenContract = await hre.ethers.getContractAt("ERC20", token);
    // console.log(`Approving ${amount} tokens for MockVault...`);
    // const approveTrx = await tokenContract.approve(mockVaultAddress, parsedAmount);
    // await approveTrx.wait();

    // // Transfer tokens to MockVault so it can pay the fee
    // console.log(`Transferring ${amount} tokens to MockVault...`);
    // const transferTrx = await tokenContract.transfer(mockVaultAddress, parsedAmount);
    // await transferTrx.wait();

    const mockVault = await hre.ethers.getContractAt(
      "MockVault",
      mockVaultAddress,
    );

    console.log(
      `Calling handleFeeWithVault on FeeHandler ${feeHandlerAddress}...`,
    );
    const trx = await mockVault.callHandleFeeWithVault(
      feeHandlerAddress,
      token,
      parsedAmount,
      beneficiary,
      creator,
    );
    const receipt = await trx.wait();

    console.log(
      `handleFeeWithVault executed successfully (tx: ${receipt?.hash})`,
    );
  });
