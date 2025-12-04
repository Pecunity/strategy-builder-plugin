import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DepositFeeHandlerModule = buildModule("DepositFeeHandlerModule", (m) => {
  const feeHandler = m.getParameter("feeHandler");
  const depositFeeHandler = m.contract("DepositFeeHandler", [feeHandler]);
  return { depositFeeHandler };
});
export default DepositFeeHandlerModule;
