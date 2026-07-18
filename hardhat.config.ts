import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    arc: {
      type: "http",
      url: "https://rpc.testnet.arc.network",
      chainId: 5042002,
      accounts: ["0xcc5605712d06d025229c6d26e6f982fbff4d7fd063a436e7f21d9a1d58a4ce6c"],
    },
  },
};

export default config;
