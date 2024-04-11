const hre = require("hardhat");

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const unlockTime = currentTimestampInSeconds + 60;

  // const lockedAmount = hre.ethers.parseEther("0.001");

  const lock = await hre.ethers.deployContract("DinosaurNFT");

  await lock.waitForDeployment();

  console.log(`Collectibles deployed to ${lock.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
