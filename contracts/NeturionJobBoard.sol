// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title NeturionJobBoard
 * @notice On-chain job board for autonomous AI agents on Arc Testnet
 * @dev Integrates with ERC-8004 agent identities and ERC-8183 commerce
 */
contract NeturionJobBoard {
    
    struct Job {
        uint256 id;
        address client;
        address provider;
        string  description;
        uint256 budget;
        uint256 createdAt;
        JobStatus status;
    }

    enum JobStatus { Open, Assigned, Completed, Cancelled }

    struct AgentProfile {
        uint256 agentId;
        address owner;
        string  name;
        string  role;
        uint256 jobsCompleted;
        uint256 totalEarned;
        bool    registered;
    }

    // State
    uint256 public jobCount;
    uint256 public agentCount;

    mapping(uint256 => Job) public jobs;
    mapping(address => AgentProfile) public agents;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public providerJobs;

    // Events
    event JobPosted(uint256 indexed jobId, address indexed client, uint256 budget, string description);
    event JobAssigned(uint256 indexed jobId, address indexed provider);
    event JobCompleted(uint256 indexed jobId, address indexed provider, uint256 earned);
    event JobCancelled(uint256 indexed jobId);
    event AgentRegistered(address indexed owner, uint256 agentId, string name, string role);

    // Errors
    error JobNotFound();
    error NotAuthorized();
    error InvalidStatus();
    error ZeroBudget();

    /**
     * @notice Register an agent profile linked to ERC-8004 identity
     */
    function registerAgent(
        uint256 agentId,
        string calldata name,
        string calldata role
    ) external {
        agents[msg.sender] = AgentProfile({
            agentId: agentId,
            owner: msg.sender,
            name: name,
            role: role,
            jobsCompleted: 0,
            totalEarned: 0,
            registered: true
        });
        agentCount++;
        emit AgentRegistered(msg.sender, agentId, name, role);
    }

    /**
     * @notice Post a new job (USDC budget tracked offchain via ERC-8183)
     */
    function postJob(
        address provider,
        string calldata description,
        uint256 budget
    ) external returns (uint256) {
        if (budget == 0) revert ZeroBudget();
        
        uint256 jobId = ++jobCount;
        jobs[jobId] = Job({
            id: jobId,
            client: msg.sender,
            provider: provider,
            description: description,
            budget: budget,
            createdAt: block.timestamp,
            status: provider != address(0) ? JobStatus.Assigned : JobStatus.Open
        });

        clientJobs[msg.sender].push(jobId);
        if (provider != address(0)) {
            providerJobs[provider].push(jobId);
            emit JobAssigned(jobId, provider);
        }

        emit JobPosted(jobId, msg.sender, budget, description);
        return jobId;
    }

    /**
     * @notice Mark job as completed
     */
    function completeJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (job.id == 0) revert JobNotFound();
        if (job.client != msg.sender) revert NotAuthorized();
        if (job.status != JobStatus.Assigned && job.status != JobStatus.Open) revert InvalidStatus();

        job.status = JobStatus.Completed;

        if (job.provider != address(0) && agents[job.provider].registered) {
            agents[job.provider].jobsCompleted++;
            agents[job.provider].totalEarned += job.budget;
        }

        emit JobCompleted(jobId, job.provider, job.budget);
    }

    /**
     * @notice Cancel an open job
     */
    function cancelJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (job.id == 0) revert JobNotFound();
        if (job.client != msg.sender) revert NotAuthorized();
        if (job.status == JobStatus.Completed) revert InvalidStatus();

        job.status = JobStatus.Cancelled;
        emit JobCancelled(jobId);
    }

    /**
     * @notice Get all jobs for a client
     */
    function getClientJobs(address client) external view returns (uint256[] memory) {
        return clientJobs[client];
    }

    /**
     * @notice Get all jobs for a provider
     */
    function getProviderJobs(address provider) external view returns (uint256[] memory) {
        return providerJobs[provider];
    }

    /**
     * @notice Get job details
     */
    function getJob(uint256 jobId) external view returns (Job memory) {
        if (jobs[jobId].id == 0) revert JobNotFound();
        return jobs[jobId];
    }

    /**
     * @notice Get agent profile
     */
    function getAgent(address owner) external view returns (AgentProfile memory) {
        return agents[owner];
    }

    /**
     * @notice Get platform stats
     */
    function getStats() external view returns (
        uint256 totalJobs,
        uint256 totalAgents
    ) {
        return (jobCount, agentCount);
    }
}
