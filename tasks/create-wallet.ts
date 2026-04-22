import { task } from "hardhat/config";
import { Wallet } from "ethers";

task("create-wallet", "Generates a new wallet").setAction(async () => {
  const wallet = Wallet.createRandom();

  console.log("🟢 New Wallet Generated:");
  console.log("Address:", wallet.address);
  console.log("Private Key:", wallet.privateKey);
});
