const hre = require("hardhat");
const { ethers, defender } = require("hardhat");
const { Verify } = require("../verifyfunc");

async function main() {
  const Factory = await ethers.getContractFactory("XGKHAN");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();

  console.log(`factory deployed to ${factory.target}`);
  await Verify(factory.target);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
