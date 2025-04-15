import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TimeConditionModule = buildModule("TimeCondition", (m) => {
  const timeCondition = m.contract("TimeCondition", []);
  return { timeCondition };
});

export default TimeConditionModule;
