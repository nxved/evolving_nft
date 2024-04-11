require("@nomicfoundation/hardhat-toolbox");
// require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    bscTestnet: {
      url: "https://wispy-hardworking-bird.bsc-testnet.discover.quiknode.pro/0df9bf19e62e2b2484b16bb51064df32dfca24ac/",
      accounts: [process.env.PRIVATE_KEY],
    },
    polygonMumbai: {
      url: "https://polygon-mumbai-bor-rpc.publicnode.com",
      accounts: [process.env.PRIVATE_KEY],
    },
  },

  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_SCAN_TESTNET_API,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
    },
  },

  sourcify: {
    enabled: true,
  },
};
