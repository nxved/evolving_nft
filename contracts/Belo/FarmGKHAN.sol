// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GKHANFarm is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public gkhanToken;
    IERC20 public xGkhanToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;
    uint256 public farmingAllocation;
    uint256 public startTime;

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 rewardRate);
    event AllocationUpdated(uint256 allocation);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            stakes[account].rewardDebt = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _gkhanToken,
        address _xGkhanToken,
        uint256 _rewardRate
    ) {
        gkhanToken = IERC20(_gkhanToken);
        xGkhanToken = IERC20(_xGkhanToken);
        rewardRate = _rewardRate;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            stakes[account]
                .amount
                .mul(rewardPerToken().sub(stakes[account].rewardDebt))
                .div(1e18)
                .add(rewards[account]);
    }

    function stake(
        uint256 amount
    ) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalSupply = totalSupply.add(amount);
        stakes[msg.sender].amount = stakes[msg.sender].amount.add(amount);
        stakes[msg.sender].rewardDebt = rewardPerTokenStored;
        gkhanToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        totalSupply = totalSupply.sub(amount);
        stakes[msg.sender].amount = stakes[msg.sender].amount.sub(amount);
        stakes[msg.sender].rewardDebt = rewardPerTokenStored;
        gkhanToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(stakes[msg.sender].amount);
        getReward();
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            xGkhanToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function updateAllocation(uint256 _farmingAllocation) external onlyOwner {
        farmingAllocation = _farmingAllocation;
        emit AllocationUpdated(_farmingAllocation);
    }

    function initializeStartTime(uint256 _startTime) external onlyOwner {
        require(startTime == 0, "Start time already initialized");
        startTime = _startTime;
        lastUpdateTime = _startTime;
    }
}
