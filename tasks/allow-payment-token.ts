import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";


task("allow-payment-token", "Allow a payment token")
    .addParam("token", "The payment token to allow")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { token } = taskArgs;
        const feeHandlerAddress = (await hre.deployments.get("FeeHandler")).address
        const feeHandler = await hre.ethers.getContractAt("FeeHandler", feeHandlerAddress);
        const trx = await feeHandler.updateTokenAllowance(token, true)
        await trx.wait()
        console.log(`Token ${token} allowed`);
    });