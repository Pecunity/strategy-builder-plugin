import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";


task("set-decimals", "Sets the decimals of a token")
    .addParam("token", "The token to set the decimals of")
    .addParam("decimals", "The number of decimals to set")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { token, decimals } = taskArgs;

        const tokenContract = await hre.ethers.getContractAt("Token", token);
        const tx = await tokenContract.setDecimals(decimals);
        await tx.wait();
        console.log(`Decimals set to ${decimals} for token ${token}`);
    })