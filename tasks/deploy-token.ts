import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";



task('deploy-token', 'Deploys the token contract').addParam('symbol', 'The symbol of the token').addParam('name', 'The name of the token').addParam('supply', 'The initial supply').setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { symbol, name, supply } = taskArgs;
    const Token = await hre.ethers.getContractFactory('Token');

    const parsedSupply = hre.ethers.parseEther(supply)

    const token = await Token.deploy(symbol, name, parsedSupply);
    const tokenAddress = await token.getAddress()
    console.log(`Token deployed at ${tokenAddress}`);

})