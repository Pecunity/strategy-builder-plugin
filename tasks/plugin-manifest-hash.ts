import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { PluginManifestStructOutput } from "../typechain-types/src/StrategyBuilderPlugin";

task("plugin-mainfest-hash").setAction(
  async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const strategyBuilderPluginAddress = (
      await hre.deployments.get("StrategyBuilderPlugin")
    ).address;

    const plugin = await hre.ethers.getContractAt(
      "StrategyBuilderPlugin",
      strategyBuilderPluginAddress
    );

    const manifest = await plugin.pluginManifest();
    const manifestString = JSON.stringify(manifest);
    console.log(manifestString);

    const hash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(manifestString));

    console.log(hash);
  }
);
