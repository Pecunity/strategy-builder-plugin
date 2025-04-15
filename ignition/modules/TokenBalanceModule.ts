import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TokenBalanceModule = buildModule(
  "ERC20TokenOrCoinBalancedCondition",
  (m) => {
    const tokenBalanceCondition = m.contract("CoinOrERC20BalanceCondition", []);
    return { tokenBalanceCondition };
  }
);
export default TokenBalanceModule;
