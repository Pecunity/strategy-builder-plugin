import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TimerConditionModule = buildModule("TimerConditionModule", (m) => {
  const timerCondition = m.contract("TimerCondition", []);
  return { timerCondition };
});

export default TimerConditionModule;
