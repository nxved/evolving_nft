require("@nomicfoundation/hardhat-toolbox");
//require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    bscTestnet: {
      url: "https://wispy-hardworking-bird.bsc-testnet.discover.quiknode.pro/0df9bf19e62e2b2484b16bb51064df32dfca24ac/",
      accounts: [process.env.KEY],
    },
    bsc: {
      url: "https://bsc-dataseed1.binance.org",
      accounts: [process.env.KEY],
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.KEY],
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.KEY],
    },
    velasMainnet: {
      url: "https://evmexplorer.velas.com/rpc",
      accounts: [process.env.KEY],
    },
    velasTestnet: {
      url: "https://evmexplorer.testnet.velas.com/rpc",
      accounts: [process.env.KEY],
    },
    polygonMumbai: {
      url: "https://polygon-mumbai.gateway.tenderly.co",
      accounts: [process.env.KEY],
    },
    polygon: {
      url: "https://polygon-pokt.nodies.app",
      accounts: [process.env.KEY],
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.KEY],
    },
    deelance: {
      url: `https://rpc.deelance.com`,
      accounts: [process.env.KEY],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHER_SCAN_TESTNET_API,
      goerli: process.env.ETHER_SCAN_TESTNET_API,
      bscTestnet: process.env.BSC_SCAN_TESTNET_API,
      bsc: process.env.BSC_SCAN_TESTNET_API,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
    },
  },

  sourcify: {
    enabled: true,
  },
};
