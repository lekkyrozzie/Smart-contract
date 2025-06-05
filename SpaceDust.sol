// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SpaceDust is ERC20, Ownable, ReentrancyGuard {
    // Token constants (in wei units for Harmony ONE)
    uint256 public constant MAX_SUPPLY = 44_000_000 * 10**18; // 44M SPDU tokens
    uint256 public constant INITIAL_PRICE = 10_000_000_000_000_000; // 0.01 ONE (in wei)
    uint256 public constant MIN_PURCHASE = 1_000_000_000_000_000;  // 0.001 ONE (in wei)
    uint256 public constant FEE_PERCENT = 100; // 1% fee (100 basis points)
    address public constant FEE_RECIPIENT = 0x60dFfcd6E4ab9Eea63aC671EA6FED8A8161c7779; // Ensure this is a Harmony ONE address!

    // State variables
    uint256 public currentPrice;
    uint256 public totalONE;
    uint256 public feeBalance;

    event TokensPurchased(address indexed buyer, uint256 oneAmount, uint256 tokensReceived);

    constructor() ERC20("SpaceDust", "SPDU") Ownable(msg.sender) {
        currentPrice = INITIAL_PRICE;
    }

    receive() external payable {
        buyTokens();
    }

    function buyTokens() public payable nonReentrant {
        require(totalSupply() < MAX_SUPPLY, "Max supply reached");
        require(msg.value >= MIN_PURCHASE, "Minimum 0.001 ONE");

        uint256 fee = (msg.value * FEE_PERCENT) / 10000; // 1% fee
        uint256 purchaseAmount = msg.value - fee;
        uint256 tokensToMint = (purchaseAmount * 10**18) / currentPrice;

        _mint(msg.sender, tokensToMint);
        feeBalance += fee;
        totalONE += msg.value;

        // Update price dynamically (avoids division by zero)
        currentPrice += (INITIAL_PRICE * totalSupply()) / (MAX_SUPPLY * 10);
        emit TokensPurchased(msg.sender, msg.value, tokensToMint);
    }

    function withdrawFees() external nonReentrant {
        require(msg.sender == FEE_RECIPIENT || msg.sender == owner(), "Unauthorized");
        require(feeBalance > 0, "No fees available");
        
        uint256 amount = feeBalance;
        feeBalance = 0;
        payable(FEE_RECIPIENT).transfer(amount);
    }

    function calculateTokensForONE(uint256 oneAmount) public view returns (uint256 tokens, uint256 fee) {
        fee = (oneAmount * FEE_PERCENT) / 10000;
        uint256 purchaseAmount = oneAmount - fee;
        tokens = (purchaseAmount * 10**18) / currentPrice;
    }
}