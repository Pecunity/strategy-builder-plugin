import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const FeeHandlerModule = buildModule("FeeHandlerModule", (m) => {
  const owner = m.getParameter("owner");
  const vault = m.getParameter("vault");
  const beneficiaryPercentage = m.getParameter("beneficiaryPercentage");
  const creatorPercentage = m.getParameter("creatorPercentage");
  const vaultPercentage = m.getParameter("vaultPercentage");

  const feeHandler = m.contract("FeeHandler", [
    owner,
    vault,
    beneficiaryPercentage,
    creatorPercentage,
    vaultPercentage,
  ]);

  return { feeHandler };
});

export default FeeHandlerModule;
