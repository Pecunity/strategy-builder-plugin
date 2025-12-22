import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MathActionModule = buildModule("MathActionModule", (m) => {
  const strategyBuilder = m.getParameter("strategyBuilderModule");

  const mathAction = m.contract("MathAction", [strategyBuilder]);

  const mathActionVault = m.contract("MathActionVault");

  return { mathAction, mathActionVault };
});

export default MathActionModule;
