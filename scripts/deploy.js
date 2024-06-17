const { ethers } = require("hardhat");

async function main() {
  const Mastermind = await ethers.getContractFactory("Mastermind");
  const mastermind = await Mastermind.deploy();

  console.log("Mastermind deployed to:", mastermind.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
