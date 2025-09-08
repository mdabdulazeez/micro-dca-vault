import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    somnia: {
      url: process.env.SOMNIA_RPC_URL || "https://rpc.somnia.network",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: parseInt(process.env.SOMNIA_CHAIN_ID || "50311"),
    },
  },
  etherscan: {
    apiKey: {
      somnia: process.env.SOMNIA_API_KEY || "dummy",
    },
    customChains: [
      {
        network: "somnia",
        chainId: parseInt(process.env.SOMNIA_CHAIN_ID || "50311"),
        urls: {
          apiURL: "https://api.somnia.network/api",
          browserURL: "https://explorer.somnia.network",
        },
      },
    ],
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
