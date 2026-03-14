import hre from "hardhat";
import path from "path";
import StrategyVaultFactoryModule from "../ignition/modules/StrategyVaultFactoryModule";

async function main() {
  await hre.ignition.deploy(StrategyVaultFactoryModule, {
    parameters: path.resolve(
      __dirname,
      `../ignition/parameters/parameters-${hre.network.name}.json`,
    ),
    displayUi: true,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
