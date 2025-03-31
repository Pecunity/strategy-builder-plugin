import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";


task("set-oracle", "Sets an oracle for a payment token")
    .addParam("token", "The payment token to set the oracle for")
    .addParam("oracleid", "The oracle to set")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const { token, oracleid: oracleId } = taskArgs;
        const oracleAddress = (await hre.deployments.get("PriceOracle")).address
        console.log(oracleAddress)
        const oracle = await hre.ethers.getContractAt("PriceOracle", oracleAddress)
        console.log(token, oracleId)
        const owner = await oracle.owner()
        console.log(owner)
        const signer = (await hre.ethers.getSigners())[0]
        console.log(signer.address)
        const trx = await oracle.setOracleID(token, oracleId)
        await trx.wait()
        console.log(`Oracle set for ${token}`);
    });
