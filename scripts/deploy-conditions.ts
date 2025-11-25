import hre from "hardhat";
import path from "path";
import TimeConditionModule from "../ignition/modules/TimeConditionModule";
import TokenBalanceModule from "../ignition/modules/TokenBalanceModule";
import DepositFeeHandlerModule from "../ignition/modules/DepositFeeHandlerModule";

async function main() {
  await hre.ignition.deploy(TimeConditionModule, {
    displayUi: true,
  });

  await hre.ignition.deploy(TokenBalanceModule, { displayUi: true });

  await hre.ignition.deploy(DepositFeeHandlerModule, {
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
