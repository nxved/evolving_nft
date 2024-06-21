const { run } = require("hardhat");

const VerifywithArgs = async (contractAddress, args) => {
  console.log("----------------------------------------------------");
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    console.log(e);
  }
};

const Verify = async (contractAddress) => {
  console.log("----------------------------------------------------");
  console.log("Verifying contract...");
  await run("verify:verify", {
    address: contractAddress,
  });
};

module.exports = { VerifywithArgs, Verify };
