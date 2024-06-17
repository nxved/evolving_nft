const hre = require("hardhat");
const { ethers, defender } = require("hardhat");

async function main() {
  const Factory = await ethers.getContractFactory("NFTBatchBurn");
  const factory = await Factory.deploy(
    "0x3EC991C2417e3FC22a2783Bf1e3D63cD4200fEF6"
  );
  await factory.waitForDeployment();

  console.log(`factory deployed to ${factory.target}`);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
