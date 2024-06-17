const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTBatchBurn", function () {
  let nftContract;
  let nftBatchBurn;
  let owner;
  let addr1;
  let addr2;
  let addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    const NFTContract = await ethers.getContractFactory("NFTContract"); // Replace with the name of your ERC721 contract
    nftContract = await NFTContract.deploy();

    const NFTBatchBurn = await ethers.getContractFactory("NFTBatchBurn");
    nftBatchBurn = await NFTBatchBurn.deploy(nftContract.target);

    // Mint some NFTs to the addresses
    await nftContract.connect(owner).mint(addr1.address, 1);
    await nftContract.connect(owner).mint(addr1.address, 2);
    await nftContract.connect(owner).mint(addr2.address, 3);
    await nftContract.connect(owner).mint(addr2.address, 4);
    await nftContract.connect(owner).mint(addr3.address, 10);
  });

  it("should burn NFTs", async function () {
    await nftContract.connect(addr1).approve(nftBatchBurn.target, 1);
    // Burn NFTs
    await expect(nftBatchBurn.connect(addr1).burnNFTs([1]))
      .to.emit(nftBatchBurn, "TokensBurned")
      .withArgs(addr1.address, 1, [1]);
  });

  it("should revert if invalid batch size is provided", async function () {
    // Connect addr2 signer to the NFTBatchBurn contract
    const nftBatchBurnAddr2 = nftBatchBurn.connect(addr2);

    // Try to burn NFTs with invalid batch size
    await expect(nftBatchBurnAddr2.burnNFTs([3, 4])).to.be.revertedWith(
      "Invalid batch size"
    );
  });

  it("should revert if sender is not owner of NFT", async function () {
    // Connect addr2 signer to the NFTBatchBurn contract
    const nftBatchBurnAddr2 = nftBatchBurn.connect(addr2);

    // Try to burn NFTs that addr2 doesn't own
    await expect(nftBatchBurnAddr2.burnNFTs([2])).to.be.revertedWith(
      "Sender is not owner of NFT"
    );
  });

  it("should revert if token is already burned", async function () {
    await nftContract.connect(addr2).approve(nftBatchBurn.target, 4);

    // Burn an NFT
    await nftBatchBurn.connect(addr2).burnNFTs([4]);

    // Try to burn the same NFT again
    await expect(nftBatchBurn.connect(addr2).burnNFTs([4])).to.be.revertedWith(
      "Sender is not owner of NFT"
    );
  });

  it("should burn 5 NFTs", async function () {
    await nftContract
      .connect(addr3)
      .setApprovalForAll(nftBatchBurn.target, true);

    // Burn NFTs
    await expect(nftBatchBurn.connect(addr3).burnNFTs([10, 11, 12, 13, 14]))
      .to.emit(nftBatchBurn, "TokensBurned")
      .withArgs(addr3.address, 5, [10, 11, 12, 13, 14]);
  });
});
