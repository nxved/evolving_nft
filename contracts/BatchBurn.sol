// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTBatchBurn {
    address public immutable burnAddress =
        0x000000000000000000000000000000000000dEaD; // Address where NFTs will be burned
    ERC721 public nftContract;

    event TokensBurned(
        address indexed sender,
        uint256 count,
        uint256[] tokenIds
    );

    mapping(uint256 => bool) public isBurned;

    constructor(address _nftContract) {
        nftContract = ERC721(_nftContract);
    }

    function burnNFTs(uint256[] calldata tokenIds) external {
        checkValidity(tokenIds);
        uint256 batchSize = tokenIds.length;

        for (uint256 i = 0; i < batchSize; i++) {
            nftContract.transferFrom(msg.sender, burnAddress, tokenIds[i]);
            isBurned[tokenIds[i]] = true;
        }

        emit TokensBurned(msg.sender, batchSize, tokenIds);
    }

    function checkValidity(uint256[] calldata tokenIds) internal view {
        uint256 batchSize = tokenIds.length;
        require(
            batchSize == 1 ||
                batchSize == 5 ||
                batchSize == 10 ||
                batchSize == 25 ||
                batchSize == 50 ||
                batchSize == 100,
            "Invalid batch size"
        );

        for (uint256 i = 0; i < batchSize; i++) {
            require(
                nftContract.ownerOf(tokenIds[i]) == msg.sender,
                "Sender is not owner of NFT"
            );
            require(!isBurned[tokenIds[i]], "Token already burned");
        }
    }
}
