import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MathActionModule = buildModule("MathActionModule", (m) => {
  const strategyBuilder = m.getParameter("strategyBuilderModule");

  const mathAction = m.contract("MathAction", [strategyBuilder]);
  return { mathAction };
});

export default MathActionModule;
