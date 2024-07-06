// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^4.3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Vesting
 * @dev A smart contract for vesting, allowing beneficiaries to unlock their tokens after a certain duration.
 */

contract Vesting is Ownable {
    uint256 public totalClaimed;

    struct VestingInfo {
        uint256 tokens;
        bool isActivated;
        uint256 activationTime;
        uint256 totalClaimedTokens;
        uint256 lastClaimed;
    }

    struct MonthInfo {
        uint256 tokens;
        uint256 releaseTime;
        bool claimed;
    }

    mapping(address => VestingInfo) public vestingInfo;
    mapping(address => mapping(uint256 => MonthInfo)) public monthlyVestingInfo;

    uint256 public vestingDuration = 12; //months
    uint256 public releaseDuration = 1200 seconds;

    event VestingActivated(
        address indexed beneficiary,
        uint256 amount,
        uint256 activationTime,
        uint256 releaseTime
    );
    event TokensClaimed(
        address indexed beneficiary,
        uint256 amount,
        uint256 month
    );
    event Withdraw(address indexed owner, uint256 amount);
    event Deposit(address indexed depositor, uint256 amount);

    constructor(
        address[] memory _originalWallets,
        uint256[] memory _claimableAmounts
    ) Ownable(msg.sender) {
        setInitialVesting(_originalWallets, _claimableAmounts);
    }

    // Admin functions

    function setInitialVesting(
        address[] memory _wallets,
        uint256[] memory _claimableAmounts
    ) public onlyOwner {
        require(
            _wallets.length == _claimableAmounts.length,
            "Array lengths do not match"
        );
        for (uint256 i = 0; i < _wallets.length; i++) {
            vestingInfo[_wallets[i]].tokens = _claimableAmounts[i];
        }
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        uint256 contractBalance = address(this).balance;
        require(contractBalance >= _amount, "Insufficient contract balance");
        (bool sent, ) = owner().call{value: _amount}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(owner(), _amount);
    }

    function removeUserFromVesting(address _user) external onlyOwner {
        require(
            vestingInfo[_user].tokens > 0,
            "User not found or has no tokens vested"
        );
        delete vestingInfo[_user];

        for (uint256 i = 1; i <= vestingDuration; i++) {
            delete monthlyVestingInfo[_user][i];
        }
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        emit Deposit(msg.sender, msg.value);
    }

    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }

    function setReleaseDuration(uint256 _duration) external onlyOwner {
        releaseDuration = _duration;
    }

    function setVestingDuration(uint256 _vestingDuration) external onlyOwner {
        vestingDuration = _vestingDuration;
    }

    function activateVesting() external {
        address _receiver = msg.sender;
        require(
            vestingInfo[_receiver].tokens > 0,
            "You are not eligible for vesting"
        );
        require(
            !vestingInfo[_receiver].isActivated,
            "Vesting already activated"
        );
        uint256 _amount = vestingInfo[_receiver].tokens;
        uint256 _activationTime = block.timestamp;

        vestingInfo[_receiver].isActivated = true;
        vestingInfo[_receiver].activationTime = _activationTime;

        uint256 monthlyTokens = _amount / vestingDuration;

        for (uint256 i = 1; i <= vestingDuration; i++) {
            monthlyVestingInfo[_receiver][i].tokens = monthlyTokens;
            monthlyVestingInfo[_receiver][i].releaseTime =
                _activationTime +
                i *
                releaseDuration;
        }

        emit VestingActivated(
            _receiver,
            _amount,
            _activationTime,
            _activationTime + 365 days
        );
    }

    function claimTokens() external {
        address receiver = msg.sender;
        require(vestingInfo[receiver].isActivated, "Vesting not activated");

        uint256 totalClaimableTokens;

        for (uint256 i = 1; i <= vestingDuration; i++) {
            if (
                !monthlyVestingInfo[receiver][i].claimed &&
                block.timestamp >= monthlyVestingInfo[receiver][i].releaseTime
            ) {
                uint256 claimableTokens = monthlyVestingInfo[receiver][i]
                    .tokens;
                monthlyVestingInfo[receiver][i].claimed = true;
                totalClaimableTokens += claimableTokens;
            }
        }

        require(totalClaimableTokens > 0, "No tokens to claim");

        (bool success, ) = receiver.call{value: totalClaimableTokens}("");
        require(success, "Failed to send Ether");

        totalClaimed += totalClaimableTokens;
        vestingInfo[receiver].totalClaimedTokens += totalClaimableTokens;
        vestingInfo[receiver].lastClaimed = block.timestamp;
    }

    function getUserVestingInfo(
        address _wallet
    )
        external
        view
        returns (
            uint256 totalTokens,
            bool isActivated,
            uint256 activationTime,
            uint256 totalClaimedTokens,
            uint256 lastClaimed,
            uint256 claimableTokens,
            MonthInfo[] memory monthlyInfo
        )
    {
        VestingInfo memory info = vestingInfo[_wallet];
        totalTokens = info.tokens;
        isActivated = info.isActivated;
        activationTime = info.activationTime;
        totalClaimedTokens = info.totalClaimedTokens;
        lastClaimed = info.lastClaimed;

        uint256 totalClaimableTokens;
        for (uint256 i = 1; i <= vestingDuration; i++) {
            if (
                info.isActivated &&
                !monthlyVestingInfo[_wallet][i].claimed &&
                block.timestamp >= monthlyVestingInfo[_wallet][i].releaseTime
            ) {
                totalClaimableTokens += monthlyVestingInfo[_wallet][i].tokens;
            }
        }

        claimableTokens = totalClaimableTokens;

        monthlyInfo = new MonthInfo[](vestingDuration);
        for (uint256 i = 0; i < vestingDuration; i++) {
            MonthInfo storage month = monthlyVestingInfo[_wallet][i + 1];
            monthlyInfo[i] = MonthInfo(
                month.tokens,
                month.releaseTime,
                month.claimed
            );
        }
    }
}
