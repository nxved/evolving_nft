// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./IERC20.sol";

contract XGKHAN is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    AccessControl,
    ERC20Permit,
    ERC20Votes
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IERC20custom public gkhanToken;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool unstaked;
    }

    mapping(address => Stake[]) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 index);
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 burnAmount,
        uint256 index
    );

    constructor() ERC20("xGKHAN", "xGKHAN") ERC20Permit("xGKHAN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        gkhanToken = IERC20custom(0x9fbAb0ac59180b3864da9a1c6E480F5Cc228991c);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 tokens");

        gkhanToken.transferFrom(msg.sender, address(this), amount);

        _mint(msg.sender, amount);

        stakes[msg.sender].push(
            Stake({amount: amount, startTime: block.timestamp, unstaked: false})
        );

        emit Staked(msg.sender, amount, stakes[msg.sender].length - 1);
    }

    function unstake(uint256 index) external {
        require(index < stakes[msg.sender].length, "Invalid stake index");
        Stake storage userStake = stakes[msg.sender][index];
        require(!userStake.unstaked, "Already unstaked");

        uint256 stakedTime = block.timestamp - userStake.startTime;
        require(stakedTime >= 10 seconds, "Minimum staking period is 10 days");

        uint256 burnPercentage;
        if (stakedTime >= 180 seconds) {
            // After 180 days, burn 2%
            burnPercentage = 2;
        } else {
            burnPercentage =
                50 -
                ((48 * (stakedTime - 10 seconds)) / (170 seconds));
        }

        uint256 burnAmount = (userStake.amount * burnPercentage) / 100;
        uint256 transferAmount = userStake.amount - burnAmount;

        _burn(msg.sender, userStake.amount);

        gkhanToken.transfer(msg.sender, transferAmount);
        gkhanToken.burnFrom(msg.sender, burnAmount);

        emit Unstaked(msg.sender, userStake.amount, burnAmount, index);

        userStake.unstaked = true;
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
