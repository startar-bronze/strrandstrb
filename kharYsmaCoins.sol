// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @custom:security-contact notairebtc@yahoo.fr
contract KharYsmaCoins is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable {
    uint256 public constant MAX_SUPPLY = 10_000_000 * 10 ** 18; // 10M tokens
    uint256 public constant PRICE_FLOOR = 550 * 10 ** 18; // Minimum price in wei
    uint256 public constant TRANSACTION_FEE_PERCENT = 10; // 10% per transaction

    address public revenueWallet; // Wallet for fee collection
    uint256 public priceFloorBalance; // Stabilization reserve

    uint256 private btcPrice; // Simulated BTC price for reference
    uint256 private ethPrice; // Simulated ETH price for reference
    uint256 private etcPrice; // Simulated ETC price for reference

    event PriceUpdated(uint256 currentPrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _revenueWallet) public initializer {
        require(_revenueWallet != address(0), "Revenue wallet is required");

        __ERC20_init("kharYsma Coins", "KHAC");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("kharYsma Coins");

        revenueWallet = _revenueWallet;
        priceFloorBalance = (MAX_SUPPLY * TRANSACTION_FEE_PERCENT) / 100;

        // Initial mint to deployer
        _mint(initialOwner, MAX_SUPPLY);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    function stabilizePrice() public {
        uint256 currentPrice = calculatePrice();
        if (currentPrice < PRICE_FLOOR) {
            uint256 tokensToBurn = (PRICE_FLOOR - currentPrice) * totalSupply() / currentPrice;
            _burn(address(this), tokensToBurn);

            // Recreate burned tokens to maintain total supply
            uint256 recreateAmount = tokensToBurn;
            _mint(owner(), recreateAmount);
        }
        emit PriceUpdated(currentPrice);
    }

    function calculatePrice() public view returns (uint256) {
        uint256 avgPrice = (btcPrice + ethPrice + etcPrice) / 3;
        uint256 currentPrice = address(this).balance / totalSupply();
        return currentPrice > avgPrice ? currentPrice : avgPrice;
    }

    function updateReferencePrices(uint256 _btcPrice, uint256 _ethPrice, uint256 _etcPrice) public onlyOwner {
        btcPrice = _btcPrice;
        ethPrice = _ethPrice;
        etcPrice = _etcPrice;
        stabilizePrice();
    }

    function marketMaking() public {
        uint256 tokensForLiquidity = balanceOf(address(this));
        uint256 ethBalance = address(this).balance;

        require(ethBalance >= PRICE_FLOOR, "Not enough ETH for market making");
        require(tokensForLiquidity > 0, "No tokens available for liquidity");

        uint256 liquidityTokens = tokensForLiquidity / 2;
        _burn(address(this), liquidityTokens); // Burn half
        _transfer(address(this), revenueWallet, liquidityTokens); // Send rest to liquidity
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        uint256 fee = (amount * TRANSACTION_FEE_PERCENT) / 100;
        uint256 ownerShare = (fee * 60) / 100; // 60% to owner (your wallet)
        uint256 liquidityShare = fee - ownerShare; // 40% to liquidity pool
        uint256 amountAfterFee = amount - fee;

        super._transfer(sender, recipient, amountAfterFee);
        if (fee > 0) {
            super._transfer(sender, revenueWallet, ownerShare);
            super._transfer(sender, address(this), liquidityShare);
        }
    }

    receive() external payable {}
}
