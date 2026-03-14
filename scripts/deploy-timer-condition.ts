import hre from "hardhat";

import TimerConditionModule from "../ignition/modules/TimerConditionModule";

async function main() {
  await hre.ignition.deploy(TimerConditionModule, {
    displayUi: true,
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
