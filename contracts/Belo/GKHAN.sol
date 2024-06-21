// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router02.sol";

contract GKHAN is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DEMAND_ROLE = keccak256("DEMAND_ROLE");

    mapping(address => bool) public _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => uint256) public dailySales;
    mapping(address => uint256) public lastSaleTime;

    uint256 public constant maxFeePercentage = 10;
    uint256 public lowDemandBuybackFee = 2;
    uint256 public lowDemandFeePool = 8;
    uint256 public highDemandBuybackFee = 0;
    uint256 public highDemandFeePool = 10;
    uint256 public buyBackPeriod = 30 days;
    uint256 public nextBuyBack;
    uint256 public normalTaxFee = 5;
    uint256 public antiWhaleThreshold = 3000000 * 10 ** decimals();
    uint256 public antiWhaleTaxFee = 25;

    bool public isLowDemandPeriod = true;
    bool private sending;
    uint256 private swapTokensAtAmount = 1000 ether;
    bool private swapping;

    address public feesPool = 0xDb3360F0a406Aa9fBbBd332Fdf64ADb688e9a769;
    address public usdt = 0x9fbAb0ac59180b3864da9a1c6E480F5Cc228991c;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    constructor() ERC20("GKHAN", "GKHAN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(DEMAND_ROLE, msg.sender);
        _mint(msg.sender, 2000000000 * 10 ** decimals());

        nextBuyBack = block.timestamp + buyBackPeriod;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );
        // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), usdt);
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        excludeFromFees(msg.sender, true);
        excludeFromFees(address(this), true);
    }

    event Buyback(uint256 amount);
    event FeesSentToPool(uint256 amount);
    event DemandPeriodChanged(bool isLowDemandPeriod);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event ExcludeFromFees(address indexed account, bool isExcluded);

    receive() external payable {}

    function calculateFee(
        uint256 amount
    ) internal view returns (uint256 buybackFee, uint256 feePool) {
        buybackFee = isLowDemandPeriod
            ? lowDemandBuybackFee
            : highDemandBuybackFee;
        feePool = isLowDemandPeriod ? lowDemandFeePool : highDemandFeePool;
        buybackFee = (amount * buybackFee) / 100;
        feePool = (amount * feePool) / 100;
    }

    function calculateSalesTax(
        uint256 amount,
        address from
    ) internal returns (uint256) {
        uint256 fee = (amount * normalTaxFee) / 100;
        if (block.timestamp > lastSaleTime[from] + 1 days) {
            dailySales[from] = amount;
        } else {
            dailySales[from] += amount;
        }
        lastSaleTime[from] = block.timestamp;
        if (dailySales[from] >= antiWhaleThreshold) {
            fee = (amount * antiWhaleTaxFee) / 100;
        }
        return fee;
    }

    // function swapSingleHopExactAmountInUSDT(uint256 amountIn) external {
    //     address[] memory path;
    //     path = new address[](2);
    //     path[0] = address(this);
    //     path[1] = usdt;

    //     uint256[] memory amounts = router.swapExactTokensForTokens(
    //         amountIn,
    //         0,
    //         path,
    //         msg.sender,
    //         block.timestamp
    //     );

    //     // amounts[0] = WETH amount, amounts[1] = DAI amount
    //     // return amounts[1];
    // }
    // function swapSingleHopExactAmountInGKHAN(uint256 amountIn) external {
    //     address[] memory path;
    //     path = new address[](2);
    //     path[0] = usdt;
    //     path[1] = address(this);

    //     weth.approve(address(router), amountInMax);

    //     uint256[] memory amounts = router.swapExactTokensForTokens(
    //         amountIn,
    //         0,
    //         path,
    //         msg.sender,
    //         block.timestamp
    //     );

    //     // amounts[0] = WETH amount, amounts[1] = DAI amount
    //     // return amounts[1];
    // }

    function swapTokensForUSDT(uint256 tokenAmount) public {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdt;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForGKHAN(uint256 tokenAmount) public {
        address[] memory path = new address[](2);
        path[0] = usdt;
        path[1] = address(this);

        IERC20(usdt).approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _beforeUpdate(address from, address to, uint256 amount) internal {
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        bool ownerFrom = hasRole(DEFAULT_ADMIN_ROLE, from);
        bool ownerTo = hasRole(DEFAULT_ADMIN_ROLE, to);

        if (
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !ownerFrom &&
            !ownerTo
        ) {
            swapping = true;
            swapTokensForUSDT(contractTokenBalance);
            swapping = false;
        }

        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));

        bool canBurnAndSend = block.timestamp > nextBuyBack;

        if (
            canBurnAndSend &&
            !sending &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            usdtBalance > 0 &&
            !ownerFrom &&
            !ownerTo
        ) {
            sending = true;
            (uint256 buybackFee, uint256 feePool) = calculateFee(usdtBalance);

            if (buybackFee > 0) {
                swapTokensForGKHAN(buybackFee);
                uint256 buyBackGKHAN = balanceOf(address(this));
                _burn(address(this), buyBackGKHAN);
                emit Buyback(buyBackGKHAN);
            }

            if (feePool > 0) {
                IERC20(usdt).transfer(feesPool, feePool);
                emit FeesSentToPool(feePool);
            }
        }

        bool takeFee = !sending;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee && automatedMarketMakerPairs[to]) {
            uint256 fees = calculateSalesTax(amount, from);
            amount = amount - fees;

            if (fees > 0) {
                super._update(from, address(this), fees);
            }
        }

        super._update(from, to, amount);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setLowDemandFees(
        uint256 buybackFee,
        uint256 feePool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            buybackFee + feePool <= maxFeePercentage,
            "Total fee cannot exceed maxFeePercentage"
        );
        lowDemandBuybackFee = buybackFee;
        lowDemandFeePool = feePool;
    }

    function setHighDemandFees(
        uint256 buybackFee,
        uint256 feePool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            buybackFee + feePool <= maxFeePercentage,
            "Total fee cannot exceed maxFeePercentage"
        );
        highDemandBuybackFee = buybackFee;
        highDemandFeePool = feePool;
    }

    function setDemandPeriod(
        bool _isLowDemandPeriod
    ) external onlyRole(DEMAND_ROLE) {
        isLowDemandPeriod = _isLowDemandPeriod;
        emit DemandPeriodChanged(_isLowDemandPeriod);
    }

    function setBuyBackTime(
        uint256 time
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        buyBackPeriod = time;
    }

    function setFeesPool(
        address _feesPool
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feesPool = _feesPool;
    }

    function updateUniswapV2Router(
        address newAddress
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            newAddress != address(uniswapV2Router),
            "updateUniswapV2Router: The router already has that address"
        );
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Pair = _uniswapV2Pair;
    }

    function excludeFromFees(
        address account,
        bool excluded
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _isExcludedFromFees[account] != excluded,
            "excludeFromFees: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            pair != uniswapV2Pair,
            "setAutomatedMarketMakerPair: The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "_setAutomatedMarketMakerPair: Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        _beforeUpdate(from, to, value);
    }
}
