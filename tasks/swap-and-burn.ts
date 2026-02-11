import { task } from "hardhat/config";
import { getDeployedAddress } from "../utils/get-deployed-address";

const BNB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c".toLowerCase();
const USDC = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d".toLowerCase();
const PEC = "0x413c2834f02003752d6Cc0Bcd1cE85Af04D62fBE".toLowerCase();
const USDT = "0x55d398326f99059ff775485246999027b3197955".toLowerCase();
const BTC = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c".toLowerCase();

task("swap-and-burn", "Swaps tokens and burns them")
  .addParam("token", "The token to swap")
  .addParam("amount", "The amount of tokens to swap")
  .setAction(async (taskArgs, hre) => {
    const swapPaths: Record<string, string> = {
      [BNB]: hre.ethers.solidityPacked(
        ["address", "uint24", "address", "uint24", "address"],
        [BNB, 100, USDC, 500, PEC],
      ),
      [USDT]: hre.ethers.solidityPacked(
        ["address", "uint24", "address", "uint24", "address"],
        [USDT, 100, USDC, 500, PEC],
      ),
      [BTC]: hre.ethers.solidityPacked(
        ["address", "uint24", "address", "uint24", "address"],
        [BTC, 100, USDC, 500, PEC],
      ),
    };

    const { token, amount } = taskArgs;

    const swapPath = swapPaths[token.toLowerCase()];
    if (!swapPath) {
      console.log(`No swap path found for token ${token}`);
      return;
    }

    const { chainId } = await hre.ethers.provider.getNetwork();

    const tokenBurnAddress = getDeployedAddress(
      "TokenBurnerModule",
      "TokenBurner",
      Number(chainId),
    );
    const tokenBurner = await hre.ethers.getContractAt(
      "TokenBurner",
      tokenBurnAddress,
    );

    const parsedAmount = hre.ethers.parseUnits(amount, 18);

    const tokenContract = await hre.ethers.getContractAt("IERC20", token);

    const actualBalance = await tokenContract.balanceOf(tokenBurnAddress);

    if (actualBalance < parsedAmount) {
      console.log(
        `actual balance is only ${hre.ethers.formatUnits(
          actualBalance,
          18,
        )}. Not valid burn amount`,
      );
      return;
    }

    console.log(
      `Burn ${hre.ethers.formatUnits(parsedAmount, 18)} ${token} in PEC...`,
    );
    const trx = await tokenBurner.swapToBurnTokenAndBurn(
      token,
      parsedAmount,
      swapPath,
      0,
    );

    await trx.wait();

    console.log(`Burned successfull: https://bscscan.com/tx/${trx.hash}`);
  });
