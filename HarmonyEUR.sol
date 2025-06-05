// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.0/contracts/security/ReentrancyGuard.sol";

contract HarmonyEUR is ERC20, Ownable, ReentrancyGuard {
    uint256 public onePriceInEUR; // ONE price in Euro cents (e.g. 175 = 1.75 EUR)
    address public constant FEE_ADDRESS = 0x60dFfcd6E4ab9Eea63aC671EA6FED8A8161c7779;

    uint256 public constant FEE_BPS = 50; // 0.5% fee
    uint256 public constant RESERVE_BPS = 200; // 2% reserve

    event HEURPurchased(address indexed buyer, uint256 heurAmount, uint256 onePaid);
    event HEURRedeemed(address indexed seller, uint256 heurAmount, uint256 oneReturned);
    event PriceUpdated(uint256 newPrice);

    constructor() ERC20("Harmony Euro", "HEUR") {}

    /// Set current price of ONE in Euro cents (e.g., 150 = €1.50)
    function setONEPriceInEUR(uint256 _priceInEuroCents) external onlyOwner {
        require(_priceInEuroCents > 0, "Price must be > 0");
        onePriceInEUR = _priceInEuroCents;
        emit PriceUpdated(_priceInEuroCents);
    }

    /// Buy HEUR by sending ONE (auto-triggered on receive too)
    receive() external payable {
        buyHEUR();
    }

    function buyHEUR() public payable nonReentrant {
        require(onePriceInEUR > 0, "Price not set");
        require(msg.value > 0, "Send ONE to buy HEUR");

        uint256 oneSent = msg.value;

        uint256 fee = (oneSent * FEE_BPS) / 10000;         // 0.5%
        uint256 reserve = (oneSent * RESERVE_BPS) / 10000; // 2%
        uint256 netAmount = oneSent - fee - reserve;

        // Calculate HEUR to mint
        uint256 heurToMint = (netAmount * onePriceInEUR * 10**18) / (1 ether * 100);

        _mint(msg.sender, heurToMint);

        // Send fee to address
        (bool sentFee, ) = payable(FEE_ADDRESS).call{value: fee}("");
        require(sentFee, "Fee transfer failed");

        emit HEURPurchased(msg.sender, heurToMint, oneSent);
    }

    /// Redeem HEUR for ONE at the fixed 1 EUR per HEUR rate
    function redeemHEUR(uint256 heurAmount) external nonReentrant {
        require(onePriceInEUR > 0, "Price not set");
        require(balanceOf(msg.sender) >= heurAmount, "Not enough HEUR");

        _burn(msg.sender, heurAmount);

        uint256 oneToSend = (heurAmount * 1 ether * 100) / (onePriceInEUR * 10**18);

        require(address(this).balance >= oneToSend, "Not enough ONE in contract");

        (bool success, ) = payable(msg.sender).call{value: oneToSend}("");
        require(success, "ONE transfer failed");

        emit HEURRedeemed(msg.sender, heurAmount, oneToSend);
    }

    /// Emergency withdraw for stuck ONE (owner only)
    function emergencyWithdrawONE(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    fallback() external payable {
        buyHEUR();
    }
}
