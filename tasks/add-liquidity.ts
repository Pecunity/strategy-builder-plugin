import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deploymentConfig, getNetworkIdFromName } from "../hardhat-deployment-config";


task("add-liquidity", "Adds liquidity to the pool")
    .addParam("tokena", "The token to add liquidity for")
    .addParam("amounta", "The amount of token to add")
    .addParam("tokenb", "The token to add liquidity for")
    .addParam("amountb", "The amount of token to add")
    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {

        const { tokena, amounta, tokenb, amountb } = taskArgs;

        const chainId = await getNetworkIdFromName(hre.network.name)

        const signer = (await hre.ethers.getSigners())[0]

        if (chainId) {
            const router = deploymentConfig[chainId].uniswapV2Router

            const routerContract = await hre.ethers.getContractAt("IUniswapV2Router01", router)

            const parsedAmountA = hre.ethers.parseEther(amounta)
            const parsedAmountB = hre.ethers.parseEther(amountb)

            const tokenA = await hre.ethers.getContractAt("IERC20", tokena)
            const tokenB = await hre.ethers.getContractAt("IERC20", tokenb)
            console.log("Approving tokens")
            await tokenA.approve(router, parsedAmountA)
            await tokenB.approve(router, parsedAmountB)

            console.log("Adding liquidity")
            const trx = await routerContract.addLiquidity(
                tokena,
                tokenb,
                parsedAmountA,
                parsedAmountB,
                0,
                0,
                signer.address,
                Date.now() + 1000 * 60 * 10
            )
            await trx.wait()

            console.log(`Added liquidity for ${amounta} ${tokena} and ${amountb} ${tokenb}`)
        }
    })