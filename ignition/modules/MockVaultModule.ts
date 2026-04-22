import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockVaultModule = buildModule("MockVaultModule", (m) => {
  const owner = m.getParameter("owner");

  const mockVault = m.contract("MockVault", [owner]);

  return { mockVault };
});

export default MockVaultModule;
