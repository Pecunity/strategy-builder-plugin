import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenBurnerModule = buildModule("TokenBurnerModule", (m) => {
  const swapRouter = m.getParameter("swapRouter");
  const burnToken = m.getParameter("burnToken");
  const feeHandler = m.getParameter("feeHandler");

  const tokenBurnerContract = m.contract("TokenBurner", [
    burnToken,
    feeHandler,
    swapRouter,
  ]);
  return { tokenBurnerContract };
});
export default TokenBurnerModule;
