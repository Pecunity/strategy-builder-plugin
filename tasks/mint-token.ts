import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";


task("mint-token", "Mints tokens")
    .addParam("token", "The token to mint")
    .addParam("amount", "The amount of tokens to mint")
    .addParam("to", "The address to mint to")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { token, amount, to } = taskArgs;

        const tokenContract = await hre.ethers.getContractAt("Token", token);

        const parsedAmount = hre.ethers.parseEther(amount)
        const tx = await tokenContract.mint(to, parsedAmount)
        await tx.wait()
        console.log(`Minted ${amount} ${token} to ${to}`);
    })