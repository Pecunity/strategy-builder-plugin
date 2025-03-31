import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";



task("check-payment-token", "Checks if a payment token is valid")
    .addParam("token", "The payment token to check")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { token } = taskArgs;
        const feeControllerAddress = (await hre.deployments.get("FeeController")).address
        const feeController = await hre.ethers.getContractAt("FeeController", feeControllerAddress);
        const valid = await feeController.hasOracle(token)

        console.log(`Token ${token} is ${valid ? "valid" : "invalid"}`);
    });