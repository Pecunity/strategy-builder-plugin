import hre from "hardhat";
import path from "path";

import StrategBuilderCoreModule from "../ignition/modules/StrategyBuilderCoreModule";

async function main() {
  await hre.ignition.deploy(StrategBuilderCoreModule, {
    parameters: path.resolve(
      __dirname,
      `../ignition/parameters/parameters-${hre.network.name}.json`
    ),
    displayUi: true,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
