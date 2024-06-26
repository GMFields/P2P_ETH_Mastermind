require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");

const { vars } = require("hardhat/config");

const INFURA_API_KEY = vars.get("INFURA_API_KEY");

const SEPOLIA_PRIVATE_KEY = vars.get("SEPOLIA_PRIVATE_KEY");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24", // Your Solidity version
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true, // Enable compilation via Intermediate Representation
    },
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
  }
  // Other Hardhat configuration settings...
};
