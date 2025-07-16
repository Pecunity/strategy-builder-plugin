import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StrategBuilderCoreModule = buildModule(
  "StrategyBuilderCoreModule",
  (m) => {
    const pythOracle = m.getParameter("pythOracle");
    const ethOracleID = m.getParameter("ethOracleID");

    // Price Oracle
    const priceOracle = m.contract("PriceOracle", [pythOracle]);
    m.call(priceOracle, "setOracleID", [
      "0x0000000000000000000000000000000000000000",
      ethOracleID,
    ]);

    // Fee Controller
    const maxFeeLimits = m.getParameter("maxFeeLimits");
    const minFeesInUSD = m.getParameter("minFeesInUSD");

    const feeController = m.contract("FeeController", [
      priceOracle,
      maxFeeLimits,
      minFeesInUSD,
    ]);

    // Fee Handler
    const vault = m.getParameter("vault");
    const beneficiaryPercentage = m.getParameter("beneficiaryPercentage");
    const creatorPercentage = m.getParameter("creatorPercentage");
    const vaultPercentage = m.getParameter("vaultPercentage");

    const feeHandler = m.contract("FeeHandler", [
      vault,
      beneficiaryPercentage,
      creatorPercentage,
      vaultPercentage,
    ]);

    // allow native coin for automation payments
    m.call(feeHandler, "updateTokenAllowance", [
      "0x0000000000000000000000000000000000000000",
      true,
    ]);

    const actionRegistry = m.contract("ActionRegistry");

    // Strategy Builder Plugin
    const strategyBuilderPlugin = m.contract("StrategyBuilderPlugin", [
      feeController,
      feeHandler,
      actionRegistry,
    ]);

    return {
      priceOracle,
      feeController,
      feeHandler,
      actionRegistry,
      strategyBuilderPlugin,
    };
  }
);

export default StrategBuilderCoreModule;
