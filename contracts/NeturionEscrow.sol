// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title NeturionEscrow
 * @notice USDC escrow for autonomous agent jobs on Arc Testnet
 * @dev Integrates with ERC-8004 agent identities
 */
contract NeturionEscrow {

    IERC20 public immutable USDC;
    address public immutable PLATFORM;
    uint256 public constant PLATFORM_FEE = 25; // 0.25%
    uint256 public constant FEE_DENOMINATOR = 10000;

    enum JobStatus { Open, Funded, Submitted, Completed, Cancelled, Disputed }

    struct Job {
        uint256 id;
        address client;
        address provider;
        address evaluator;
        uint256 amount;
        uint256 platformFee;
        uint256 createdAt;
        uint256 deadline;
        string  description;
        JobStatus status;
        bytes32 deliveryHash;
    }

    uint256 public jobCount;
    mapping(uint256 => Job) public jobs;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public providerJobs;

    event JobCreated(uint256 indexed jobId, address indexed client, address indexed provider, uint256 amount);
    event JobFunded(uint256 indexed jobId, uint256 amount);
    event JobDelivered(uint256 indexed jobId, bytes32 deliveryHash);
    event JobCompleted(uint256 indexed jobId, address provider, uint256 paid);
    event JobCancelled(uint256 indexed jobId, address client, uint256 refund);
    event JobDisputed(uint256 indexed jobId);

    error Unauthorized();
    error InvalidStatus();
    error InvalidAmount();
    error TransferFailed();
    error DeadlinePassed();

    constructor(address _usdc, address _platform) {
        USDC = IERC20(_usdc);
        PLATFORM = _platform;
    }

    /**
     * @notice Create and fund a job in one transaction
     */
    function createAndFund(
        address provider,
        address evaluator,
        string calldata description,
        uint256 amount,
        uint256 durationDays
    ) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        uint256 fee = (amount * PLATFORM_FEE) / FEE_DENOMINATOR;
        uint256 total = amount + fee;

        bool ok = USDC.transferFrom(msg.sender, address(this), total);
        if (!ok) revert TransferFailed();

        uint256 jobId = ++jobCount;
        jobs[jobId] = Job({
            id: jobId,
            client: msg.sender,
            provider: provider,
            evaluator: evaluator == address(0) ? msg.sender : evaluator,
            amount: amount,
            platformFee: fee,
            createdAt: block.timestamp,
            deadline: block.timestamp + (durationDays * 86400),
            description: description,
            status: JobStatus.Funded,
            deliveryHash: bytes32(0)
        });

        clientJobs[msg.sender].push(jobId);
        if (provider != address(0)) providerJobs[provider].push(jobId);

        emit JobCreated(jobId, msg.sender, provider, amount);
        emit JobFunded(jobId, amount);
        return jobId;
    }

    /**
     * @notice Provider submits delivery hash
     */
    function submitDelivery(uint256 jobId, bytes32 deliveryHash) external {
        Job storage job = jobs[jobId];
        if (job.provider != msg.sender) revert Unauthorized();
        if (job.status != JobStatus.Funded) revert InvalidStatus();
        if (block.timestamp > job.deadline) revert DeadlinePassed();

        job.status = JobStatus.Submitted;
        job.deliveryHash = deliveryHash;
        emit JobDelivered(jobId, deliveryHash);
    }

    /**
     * @notice Client or evaluator approves delivery — releases USDC to provider
     */
    function approveDelivery(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (msg.sender != job.client && msg.sender != job.evaluator) revert Unauthorized();
        if (job.status != JobStatus.Submitted && job.status != JobStatus.Funded) revert InvalidStatus();

        job.status = JobStatus.Completed;

        bool ok = USDC.transfer(job.provider, job.amount);
        if (!ok) revert TransferFailed();

        USDC.transfer(PLATFORM, job.platformFee);

        emit JobCompleted(jobId, job.provider, job.amount);
    }

    /**
     * @notice Client cancels — refund if not submitted
     */
    function cancelJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (job.client != msg.sender) revert Unauthorized();
        if (job.status != JobStatus.Funded && job.status != JobStatus.Open) revert InvalidStatus();

        job.status = JobStatus.Cancelled;
        uint256 refund = job.amount + job.platformFee;

        bool ok = USDC.transfer(job.client, refund);
        if (!ok) revert TransferFailed();

        emit JobCancelled(jobId, msg.sender, refund);
    }

    /**
     * @notice Raise dispute
     */
    function disputeJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (msg.sender != job.client && msg.sender != job.provider) revert Unauthorized();
        if (job.status != JobStatus.Submitted && job.status != JobStatus.Funded) revert InvalidStatus();
        job.status = JobStatus.Disputed;
        emit JobDisputed(jobId);
    }

    /**
     * @notice Platform resolves dispute
     */
    function resolveDispute(uint256 jobId, bool payProvider) external {
        if (msg.sender != PLATFORM) revert Unauthorized();
        Job storage job = jobs[jobId];
        if (job.status != JobStatus.Disputed) revert InvalidStatus();

        job.status = JobStatus.Completed;
        address recipient = payProvider ? job.provider : job.client;

        USDC.transfer(recipient, job.amount);
        USDC.transfer(PLATFORM, job.platformFee);

        emit JobCompleted(jobId, recipient, job.amount);
    }

    function getJob(uint256 jobId) external view returns (Job memory) {
        return jobs[jobId];
    }

    function getClientJobs(address client) external view returns (uint256[] memory) {
        return clientJobs[client];
    }

    function getProviderJobs(address provider) external view returns (uint256[] memory) {
        return providerJobs[provider];
    }

    function getEscrowBalance() external view returns (uint256) {
        return USDC.balanceOf(address(this));
    }
}
