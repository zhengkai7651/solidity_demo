// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CrowdFund
 * @dev 学习用途众筹合约
 */
contract CrowdFund {
    // 众筹状态枚举
    // Ongoing: 众筹进行中
    // Success: 众筹成功
    // Failed: 众筹失败
    enum FundStatus {
        Ongoing,
        Success,
        Failed
    }

    // 捐赠者信息结构体
    struct DonorInfo {
        uint256 donateAmount; // 捐赠金额
        bool hasRefunded; // 是否已退款
    }

    
    address public immutable creator; // 众筹发起者
    uint256 public immutable targetAmount; // 目标金额
    uint256 public immutable deadline; // 众筹截止时间
    uint256 public totalCollected; // 已收集金额
    FundStatus public status; // 众筹状态

    mapping(address => DonorInfo) public donorMap; // 捐赠者 => 捐赠者信息
    address[] public donorList; // 捐赠者列表

    error FundEnded(); // 众筹已结束
    error NotCreator(); // 不是众筹发起者
    error NotDonor(); // 不是捐赠者
    error AlreadyRefunded(); // 已退款
    error FundNotEnd(); // 众筹未结束
    error WithdrawNotSuccess(); // 众筹发起者未成功提现
    error RefundNotFailed(); // 众筹失败时未成功退款
    error ZeroDonate(); // 捐赠金额为0
    
    // 仅允许众筹发起者调用
    modifier onlyCreator() {
        if (msg.sender != creator) revert NotCreator();
        _;
    }
    
    // 仅允许众筹进行中时调用
    modifier onlyOngoing() {
        if (block.timestamp >= deadline) revert FundEnded();
        _;
    }
    
    // 仅允许众筹已结束时调用
    modifier onlyEnded() {
        if (block.timestamp < deadline) revert FundNotEnd();
        _;
    }

    // 众筹合约构造函数
    constructor(uint256 _targetAmount, uint256 _durationSeconds) {
        creator = msg.sender;
        targetAmount = _targetAmount; 
        deadline = block.timestamp + _durationSeconds;
        status = FundStatus.Ongoing;
    }

    // 接收ETH
    receive() external payable onlyOngoing {
        _donate();
    }

    // 接收ETH
    fallback() external payable onlyOngoing {
        _donate();
    }
    
    // 捐赠ETH
    function contribute() external payable onlyOngoing {
        _donate();
    }

    // 捐赠ETH
    function _donate() internal {
        if (msg.value == 0) revert ZeroDonate();
        DonorInfo storage info = donorMap[msg.sender];
        if (info.donateAmount == 0) {
            donorList.push(msg.sender);
        }
        info.donateAmount += msg.value;
        totalCollected += msg.value;
    }

    // 结算众筹
    function settleFund() external onlyEnded {
        if (status != FundStatus.Ongoing) return;
        if (totalCollected >= targetAmount) {
            status = FundStatus.Success;
        } else {
            status = FundStatus.Failed;
        }
    }

    // 众筹发起者提现ETH
    function creatorWithdraw() external onlyCreator {
        if (status != FundStatus.Success) revert WithdrawNotSuccess();
        uint256 amount = totalCollected;
        totalCollected = 0;
        (bool ok, ) = payable(creator).call{value: amount}("");
        require(ok, "transfer failed");
    }

    // 众筹失败时退款ETH
    function batchRefund() external onlyEnded {
        if (status != FundStatus.Failed) revert RefundNotFailed();
        uint256 len = donorList.length;
        for (uint256 i = 0; i < len; ) {
            address user = donorList[i];
            DonorInfo storage info = donorMap[user];
            if (info.donateAmount == 0 || info.hasRefunded) {
                unchecked { ++i; }
                continue;
            }
            uint256 refundAmt = info.donateAmount;
            info.hasRefunded = true;
            info.donateAmount = 0;
            (bool ok, ) = payable(user).call{value: refundAmt}("");
            if (!ok) break;
            unchecked { ++i; }
        }
    }

    // 获取捐赠者信息
    function getDonorInfo(address _user) external view returns (uint256 amount, bool refunded) {
        DonorInfo memory d = donorMap[_user];
        amount = d.donateAmount;
        refunded = d.hasRefunded;
    }

    // 获取剩余时间
    function getRemainTime() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    // 检查是否已收集到目标金额
    function isEnough(uint256 collected, uint256 target) external pure returns (bool) {
        return collected >= target;
    }

    // 获取合约当前收到的总ETH（wei）
    function getTotalAmout() external view returns(uint256) {
        return address(this).balance;
    }
}
