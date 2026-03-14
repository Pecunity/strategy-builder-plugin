import hre from "hardhat";
import path from "path";
import FeeHandlerModule from "../ignition/modules/FeeHandlerModule";

async function main() {
  await hre.ignition.deploy(FeeHandlerModule, {
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
