// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFT {
    function balanceOf(address owner) external view returns (uint256);
}

contract FreelancePlatform {
    address public platform;
    address public admin;
    INFT public nftContract;

    uint256 public jobCount;
    uint256 public buyerFeePercentage;
    uint256 public sellerFeePercentage;

    struct Job {
        uint256 jobId;
        address buyer;
        address seller;
        uint256 amount;
        bool buyerIsNFTHolder;
        bool isPaid;
        bool isDisputed;
    }

    mapping(uint256 => Job) public jobs;

    event JobCreated(
        uint256 jobId,
        address buyer,
        address seller,
        uint256 amount,
        bool buyerIsNFTHolder
    );
    event JobCompleted(uint256 jobId);
    event DisputeRaised(uint256 jobId);
    event DisputeResolved(
        uint256 jobId,
        uint256 platformFeeFromBuyer,
        uint256 platformFeeFromSeller,
        uint256 sellerAmount
    );

    constructor(address _nftContract, address _admin) {
        platform = msg.sender;
        nftContract = INFT(_nftContract);
        admin = _admin;
        buyerFeePercentage = 2;
        sellerFeePercentage = 10;
    }

    modifier onlyPlatform() {
        require(msg.sender == platform, "Only platform can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function updateNFTContract(address _nftContract) public onlyPlatform {
        nftContract = INFT(_nftContract);
    }

    function setBuyerFeePercentage(uint256 _percentage) public onlyPlatform {
        buyerFeePercentage = _percentage;
    }

    function setSellerFeePercentage(uint256 _percentage) public onlyPlatform {
        sellerFeePercentage = _percentage;
    }

    function validateNFTHolder(address _buyer) internal view returns (bool) {
        return nftContract.balanceOf(_buyer) > 0;
    }

    function createJob(address _seller) public payable {
        require(msg.value > 0, "Gig amount must be greater than zero");

        jobCount++;
        uint256 jobId = jobCount;
        bool isNFTHolder = validateNFTHolder(msg.sender);

        jobs[jobId] = Job({
            jobId: jobId,
            buyer: msg.sender,
            seller: _seller,
            amount: msg.value,
            buyerIsNFTHolder: isNFTHolder,
            isPaid: false,
            isDisputed: false
        });

        emit JobCreated(jobId, msg.sender, _seller, msg.value, isNFTHolder);
    }

    function completeJob(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.buyer, "Only buyer can complete the job");
        require(!job.isPaid, "Job already paid");
        require(!job.isDisputed, "Job is disputed");

        uint256 platformFeeFromBuyer;
        uint256 platformFeeFromSeller = (job.amount * sellerFeePercentage) /
            100;
        if (!job.buyerIsNFTHolder) {
            platformFeeFromBuyer = (job.amount * buyerFeePercentage) / 100; // Buyer fee
        } else {
            platformFeeFromBuyer = 0;
        }

        uint256 sellerAmount = job.amount -
            platformFeeFromBuyer -
            platformFeeFromSeller;

        payable(platform).transfer(
            platformFeeFromBuyer + platformFeeFromSeller
        );

        payable(job.seller).transfer(sellerAmount);

        job.isPaid = true;

        emit JobCompleted(_jobId);
    }

    function raiseDispute(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(
            msg.sender == job.buyer || msg.sender == job.seller,
            "Only buyer or seller can raise dispute"
        );
        require(!job.isPaid, "Job already paid");

        job.isDisputed = true;

        emit DisputeRaised(_jobId);
    }

    function resolveDispute(
        uint256 _jobId,
        uint256 _buyerAmount,
        uint256 _sellerAmount
    ) public onlyAdmin {
        Job storage job = jobs[_jobId];
        require(job.isDisputed, "Job is not disputed");

        uint256 platformFeeFromBuyer = 0;
        uint256 platformFeeFromSeller = 0;

        if (!job.buyerIsNFTHolder) {
            platformFeeFromBuyer = (_buyerAmount * buyerFeePercentage) / 100; // Buyer fee
        }

        platformFeeFromSeller = (_sellerAmount * sellerFeePercentage) / 100; // Seller fee

        uint256 totalPlatformFee = platformFeeFromBuyer + platformFeeFromSeller;
        uint256 totalAmount = job.amount;

        require(
            _buyerAmount + _sellerAmount + totalPlatformFee == totalAmount,
            "Total amount does not match job amount"
        );

        payable(platform).transfer(totalPlatformFee);

        if (_buyerAmount > 0) {
            payable(job.buyer).transfer(_buyerAmount);
        }
        if (_sellerAmount > 0) {
            payable(job.seller).transfer(_sellerAmount);
        }

        job.isPaid = true;
        job.isDisputed = false;

        emit DisputeResolved(
            _jobId,
            platformFeeFromBuyer,
            platformFeeFromSeller,
            _sellerAmount
        );
    }
}
