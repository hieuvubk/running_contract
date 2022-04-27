  
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BoneToken.sol";

// BoneMasterChef is the master of Bone. He can make Bone and he is a fair guy.
// The biggest change made is using per second instead of per block for rewards
// This is due to Fantoms extremely inconsistent block times
// The other biggest change was the removal of the migration functions
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once BONE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract BoneMasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of BONEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // BONE tokens created per second.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early bone makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    uint256 public startTime;
    // The block time when BONE mining ends because it has total supply.
    uint256 public endTime;
    // Last block number that BONEs distribution occurs.
    uint256 lastRewardBlock;

    uint256 accTokenPerShare;

    uint256 totalSupply;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);

    constructor(
        BoneToken _bone,
        uint256 _bonePerSecond,
        uint256 _startTime,
        uint256 _endTime
    ) {
        bone = _bone;
        tokenPerBlock = _bonePerSecond;
        startTime = _startTime;
        endTime = _endTime;
        lastRewardBlock = startTime;
        accTokenPerShare = 0;
    }

    function updateMultiplier(uint256 multiplierNumber) external onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        _from = _from > startTime ? _from : startTime;
        _to = _to > endTime ? endTime: _to;

        if (_to < startTime || _from > endTime) return 0;
        return _to - _from;
    }

    // View function to see pending BONEs on frontend.
    function pendingToken(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (block.number > lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp);
            uint256 boneReward = multiplier.mul(tokenPerBlock);            
            accTokenPerShare = accTokenPerShare.add(boneReward.div(lpSupply));
        }
        return user.amount.mul(accTokenPerShare).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        if (block.timestamp <= lastRewardBlock) {
            return;
        }
        if (totalSupply == 0) {
            lastRewardBlock = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock, block.timestamp);
        uint256 boneReward = multiplier.mul(tokenPerBlock);

        bone.mint(devAddr, boneReward.div(10)); // 10% is dev reward
        bone.mint(address(this), boneReward);

        accTokenPerShare = accTokenPerShare.add(boneReward.div(totalSupply));
        pool.lastRewardBlock = block.timestamp;
    }

    // Deposit LP tokens to BoneMasterChef for BONE allocation.
    function deposit(uint256 _amount) external {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accTokenPerShare).sub(user.rewardDebt);
            if(pending > 0) {
                safeTokenTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFee > 0) {
                uint256 depositFee = _amount.mul(pool.depositFee).div(10000);
                pool.lpToken.safeTransfer(feeAddr, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from BoneMasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeTokenTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe bone transfer function, just in case if rounding error causes pool to not have enough BONEs.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 boneBal = bone.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > boneBal) {
            transferSuccess = bone.transfer(_to, boneBal);
        } else {
            transferSuccess = bone.transfer(_to, _amount);
        }
        require(transferSuccess, "safeTokenTransfer: transfer failed");
    }

    // Update dev address by the previous dev.
    function dev(address _devAddr) external {
        require(msg.sender == devAddr, "dev: wut?");
        devAddr = _devAddr;

        emit SetDevAddress(msg.sender, _devAddr);
    }
    
    // Update fee address by the previous fee manager.
    function setFeeAddress(address _feeAddr) external {
        require(msg.sender == feeAddr, "setFeeAddress: Forbidden");
        feeAddr = _feeAddr;

        emit SetFeeAddress(msg.sender, _feeAddr);
    }

    function updateStartTime(uint256 _startTime) external onlyOwner {
        require(block.timestamp < startTime, "Staking was started already");
        require(block.timestamp < _startTime);
        
        startTime = _startTime;
        endTime = _startTime.add(uint256(7200000 ether).div(tokenPerBlock.mul(110).div(100)));
    }
}