import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StrategyVaultFactoryModule = buildModule(
  "StrategyVaultFactoryModule",
  (m) => {
    const feeController = m.getParameter("feeController");
    const feeHandler = m.getParameter("feeHandler");
    const actionRegistry = m.getParameter("actionRegistry");

    const strategyVaultImplementation = m.contract("StrategyVault");

    const strategyVaultFactory = m.contract("StrategyVaultFactory", [
      feeController,
      feeHandler,
      actionRegistry,
      strategyVaultImplementation,
    ]);

    return { strategyVaultFactory };
  },
);

export default StrategyVaultFactoryModule;
