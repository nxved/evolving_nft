// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface INFT {
    function balanceOf(address owner) external view returns (uint256);
}

contract DeelancePlatform is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public platform;
    INFT public nftContract;

    uint256 public jobCount;
    uint256 public openTaskCount;
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
        uint256 deadline;
        uint256 revisionCount;
        uint256 revisionRequests;
        uint256 lastRevisionRequestTime;
        bool openForRevision;
    }

    struct OpenTask {
        uint256 taskId;
        address company;
        uint256 bounty;
        address[] submissions;
        bool isPaid;
    }

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => OpenTask) public openTasks;

    event JobCreated(
        uint256 jobId,
        address buyer,
        address seller,
        uint256 amount,
        bool buyerIsNFTHolder,
        uint256 deadline,
        uint256 revisionCount
    );
    event JobCompleted(uint256 jobId);
    event DisputeRaised(uint256 jobId);
    event DisputeResolved(
        uint256 jobId,
        uint256 platformFeeFromBuyer,
        uint256 platformFeeFromSeller,
        uint256 sellerAmount
    );
    event RevisionRequested(uint256 jobId);
    event RevisionCompleted(uint256 jobId);
    event RefundClaimed(uint256 jobId);
    event OpenTaskCreated(uint256 taskId, address company, uint256 bounty);
    event TaskSubmission(uint256 taskId, address submitter);
    event TaskRewarded(uint256 taskId, address winner, uint256 bounty);

    constructor(address _nftContract, address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _admin);
        platform = msg.sender;
        nftContract = INFT(_nftContract);
        buyerFeePercentage = 2;
        sellerFeePercentage = 10;
    }

    function updateNFTContract(
        address _nftContract
    ) public onlyRole(ADMIN_ROLE) {
        nftContract = INFT(_nftContract);
    }

    function setBuyerFeePercentage(
        uint256 _percentage
    ) public onlyRole(ADMIN_ROLE) {
        buyerFeePercentage = _percentage;
    }

    function setSellerFeePercentage(
        uint256 _percentage
    ) public onlyRole(ADMIN_ROLE) {
        sellerFeePercentage = _percentage;
    }

    function setPlatform(address _platform) public onlyRole(ADMIN_ROLE) {
        platform = _platform;
    }

    function validateNFTHolder(address _buyer) internal view returns (bool) {
        return nftContract.balanceOf(_buyer) > 0;
    }

    function createJob(
        address _seller,
        uint256 _deadline,
        uint256 _revisionCount
    ) public payable whenNotPaused {
        require(msg.value > 0, "Gig amount must be greater than zero");
        require(_deadline > block.timestamp, "Deadline must be in the future");

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
            isDisputed: false,
            deadline: _deadline,
            revisionCount: _revisionCount,
            revisionRequests: 0,
            lastRevisionRequestTime: 0,
            openForRevision: false
        });

        emit JobCreated(
            jobId,
            msg.sender,
            _seller,
            msg.value,
            isNFTHolder,
            _deadline,
            _revisionCount
        );
    }

    function completeJob(uint256 _jobId) public whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.buyer, "Only buyer can complete the job");
        require(!job.isPaid, "Job already paid");
        require(!job.isDisputed, "Job is disputed");

        uint256 platformFeeFromBuyer;
        uint256 platformFeeFromSeller = (job.amount * sellerFeePercentage) /
            100;

        if (!job.buyerIsNFTHolder) {
            platformFeeFromBuyer = (job.amount * buyerFeePercentage) / 100;
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

    function claimPayment(uint256 _jobId) public whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.seller, "Only seller can claim payment");
        require(!job.isPaid, "Job already paid");
        require(
            block.timestamp > job.deadline + 15 days,
            "Claim period not reached"
        );
        require(
            job.openForRevision && !job.isDisputed,
            "Job has pending revisions or disputes"
        );

        uint256 platformFeeFromBuyer;
        uint256 platformFeeFromSeller = (job.amount * sellerFeePercentage) /
            100;

        if (!job.buyerIsNFTHolder) {
            platformFeeFromBuyer = (job.amount * buyerFeePercentage) / 100;
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

    function raiseDispute(uint256 _jobId) public whenNotPaused {
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
    ) public onlyRole(ADMIN_ROLE) {
        Job storage job = jobs[_jobId];
        require(job.isDisputed, "Job is not disputed");

        uint256 platformFeeFromBuyer = 0;
        uint256 platformFeeFromSeller = 0;

        if (!job.buyerIsNFTHolder) {
            platformFeeFromBuyer = (_buyerAmount * buyerFeePercentage) / 100;
        }

        platformFeeFromSeller = (_sellerAmount * sellerFeePercentage) / 100;

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

    function requestRevision(uint256 _jobId) public whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.buyer, "Only buyer can request revision");
        require(!job.isPaid, "Job already paid");
        require(
            job.revisionRequests <= job.revisionCount,
            "Revision limit reached"
        );
        require(!job.isDisputed, "Job is disputed");

        job.revisionRequests++;
        job.lastRevisionRequestTime = block.timestamp;
        job.openForRevision = true;
        emit RevisionRequested(_jobId);
    }

    function claimRefund(uint256 _jobId) public whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.buyer, "Only buyer can claim refund");
        require(!job.isPaid, "Job already paid");
        require(
            block.timestamp > job.lastRevisionRequestTime + 5 days,
            "Refund period not reached"
        );
        require(job.openForRevision, "Revision is not Open");

        require(!job.isDisputed, "Job is disputed");

        uint256 refundAmount = job.amount;

        payable(job.buyer).transfer(refundAmount);

        job.isPaid = true;

        emit RefundClaimed(_jobId);
    }

    function closeRevision(uint256 _jobId) public whenNotPaused {
        Job storage job = jobs[_jobId];
        require(
            msg.sender == job.seller,
            "Only seller can complete the revision"
        );
        require(job.revisionRequests > 0, "No revision requested");

        job.openForRevision = false;
        emit RevisionCompleted(_jobId);
    }

    function createOpenTask(uint256 _bounty) public whenNotPaused {
        require(_bounty > 0, "Bounty must be greater than zero");

        openTaskCount++;
        uint256 taskId = openTaskCount;

        openTasks[taskId] = OpenTask({
            taskId: taskId,
            company: msg.sender,
            bounty: _bounty,
            submissions: new address[](0),
            isPaid: false
        });

        emit OpenTaskCreated(taskId, msg.sender, _bounty);
    }

    function submitToTask(uint256 _taskId) public whenNotPaused {
        OpenTask storage task = openTasks[_taskId];
        require(!task.isPaid, "Task already paid");

        task.submissions.push(msg.sender);

        emit TaskSubmission(_taskId, msg.sender);
    }

    function rewardTask(uint256 _taskId, address _winner) public whenNotPaused {
        OpenTask storage task = openTasks[_taskId];
        require(
            msg.sender == task.company,
            "Only the company can reward the task"
        );
        require(!task.isPaid, "Task already paid");

        payable(_winner).transfer(task.bounty);

        task.isPaid = true;

        emit TaskRewarded(_taskId, _winner, task.bounty);
    }
}
