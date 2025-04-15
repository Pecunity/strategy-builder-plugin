import hre from "hardhat";
import TimeConditionModule from "../ignition/modules/TimeConditionModule";
import TokenBalanceModule from "../ignition/modules/TokenBalanceModule";

async function main() {
  await hre.ignition.deploy(TimeConditionModule, {
    displayUi: true,
  });

  await hre.ignition.deploy(TokenBalanceModule, { displayUi: true });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
