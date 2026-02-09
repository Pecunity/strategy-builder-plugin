import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const PecunityOracleModule = buildModule("PecunityOracleModule", (m) => {
  const updater = m.getParameter("updater");

  const pecunityOracle = m.contract("PecunityOracle");

  m.call(pecunityOracle, "setUpdater", [updater, true]);

  return { pecunityOracle };
});

export default PecunityOracleModule;
