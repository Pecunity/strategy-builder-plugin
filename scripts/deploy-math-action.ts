import hre from "hardhat";
import path from "path";
import MathActionModule from "../ignition/modules/MathActionModule";

async function main() {
  await hre.ignition.deploy(MathActionModule, {
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
