// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OptimizedONEStaker {
    IERC20 public immutable ONE;
    address public immutable feeCollector;
    
    // Hardcoded parameters
    uint256 public constant MIN_STAKE = 100 ether; // 100 ONE (1e18 wei)
    uint256 public constant TOTAL_APY = 15; // 15% APY
    uint256 public constant USER_SHARE = 70; // 70% of rewards (updated)
    uint256 public constant FEE_SHARE = 30; // 30% of rewards (updated)
    uint256 public constant EPOCH_DURATION = 18.2 hours; // Harmony epochs
    uint256 public constant UNSTAKE_DELAY = 1; // 1 epoch wait

    // Stake tracking
    struct Stake {
        uint256 amount;
        uint256 lastClaimEpoch;
        uint256 unstakeRequestEpoch;
    }
    mapping(address => Stake) public stakes;

    // Epoch management
    uint256 public currentEpoch;
    uint256 public lastEpochUpdate;

    constructor(address _oneToken, address _feeCollector) {
        ONE = IERC20(_oneToken);
        feeCollector = _feeCollector;
        currentEpoch = 1;
        lastEpochUpdate = block.timestamp;
    }

    // Update epoch counter
    modifier updateEpoch() {
        uint256 epochsPassed = (block.timestamp - lastEpochUpdate) / EPOCH_DURATION;
        if (epochsPassed > 0) {
            currentEpoch += epochsPassed;
            lastEpochUpdate += epochsPassed * EPOCH_DURATION;
        }
        _;
    }

    // Stake 100+ ONE (enforces minimum)
    function stake(uint256 _amount) external updateEpoch {
        require(_amount >= MIN_STAKE, "Minimum 100 ONE");
        _claimRewards(msg.sender);
        
        stakes[msg.sender] = Stake({
            amount: stakes[msg.sender].amount + _amount,
            lastClaimEpoch: currentEpoch,
            unstakeRequestEpoch: 0
        });
        
        ONE.transferFrom(msg.sender, address(this), _amount);
    }

    // Request unstake (marks epoch)
    function requestUnstake() external updateEpoch {
        require(stakes[msg.sender].amount > 0, "No stake");
        stakes[msg.sender].unstakeRequestEpoch = currentEpoch;
    }

    // Withdraw after 1 epoch (returns full stake + claims rewards)
    function withdraw() external updateEpoch {
        Stake storage s = stakes[msg.sender];
        require(s.unstakeRequestEpoch > 0, "No unstake request");
        require(currentEpoch > s.unstakeRequestEpoch, "Must wait 1 epoch");
        
        _claimRewards(msg.sender);
        uint256 amount = s.amount;
        s.amount = 0; // Reset stake
        
        ONE.transfer(msg.sender, amount); // Original stake returned 100%
    }

    // Claim rewards (70% user / 30% fee) - Updated split
    function _claimRewards(address _staker) private {
        Stake storage s = stakes[_staker];
        if (s.amount == 0) return;

        uint256 epochsElapsed = currentEpoch - s.lastClaimEpoch;
        if (epochsElapsed == 0) return;

        // Calculate rewards for elapsed epochs (15% APY)
        uint256 rewards = (s.amount * TOTAL_APY * epochsElapsed * EPOCH_DURATION) / (365 days * 100);
        
        if (rewards > 0) {
            uint256 fee = (rewards * FEE_SHARE) / 100;
            uint256 userReward = rewards - fee;

            ONE.transfer(_staker, userReward);
            ONE.transfer(feeCollector, fee);
            s.lastClaimEpoch = currentEpoch;
        }
    }

    // Manual reward claim
    function claimRewards() external updateEpoch {
        _claimRewards(msg.sender);
    }
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}