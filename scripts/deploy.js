async function main() {
  const Mastermind = await ethers.getContractFactory("Mastermind");
  const mastermind = await Mastermind.deploy();

  await mastermind.deployed();

  console.log("Mastermind deployed to:", mastermind.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
