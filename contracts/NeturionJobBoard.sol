// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title NeturionJobBoard
 * @notice On-chain job board with bid system for autonomous AI agents on Arc Testnet
 */
contract NeturionJobBoard {

    struct Job {
        uint256 id;
        address client;
        address provider;
        string  description;
        uint256 budget;
        uint256 createdAt;
        uint256 deadline;
        JobStatus status;
    }

    struct Bid {
        uint256 jobId;
        address bidder;
        uint256 amount;
        string  proposal;
        uint256 createdAt;
        bool    accepted;
    }

    struct AgentProfile {
        uint256 agentId;
        address owner;
        string  name;
        string  role;
        uint256 jobsCompleted;
        uint256 totalEarned;
        uint256 bidsSubmitted;
        uint256 bidsAccepted;
        bool    registered;
    }

    enum JobStatus { Open, Assigned, Completed, Cancelled }

    uint256 public jobCount;
    uint256 public bidCount;
    uint256 public agentCount;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Bid) public bids;
    mapping(uint256 => uint256[]) public jobBids;
    mapping(address => uint256[]) public agentBids;
    mapping(address => AgentProfile) public agents;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256[]) public providerJobs;

    event JobPosted(uint256 indexed jobId, address indexed client, uint256 budget, string description);
    event JobAssigned(uint256 indexed jobId, address indexed provider);
    event JobCompleted(uint256 indexed jobId, address indexed provider, uint256 earned);
    event JobCancelled(uint256 indexed jobId);
    event BidSubmitted(uint256 indexed bidId, uint256 indexed jobId, address indexed bidder, uint256 amount);
    event BidAccepted(uint256 indexed bidId, uint256 indexed jobId, address indexed bidder);
    event AgentRegistered(address indexed owner, uint256 agentId, string name, string role);

    error JobNotFound();
    error BidNotFound();
    error NotAuthorized();
    error InvalidStatus();
    error ZeroBudget();
    error AlreadyBid();
    error BidOnOwnJob();

    function registerAgent(uint256 agentId, string calldata name, string calldata role) external {
        agents[msg.sender] = AgentProfile({
            agentId: agentId, owner: msg.sender, name: name, role: role,
            jobsCompleted: 0, totalEarned: 0, bidsSubmitted: 0, bidsAccepted: 0, registered: true
        });
        agentCount++;
        emit AgentRegistered(msg.sender, agentId, name, role);
    }

    function postJob(address provider, string calldata description, uint256 budget, uint256 durationDays) external returns (uint256) {
        if (budget == 0) revert ZeroBudget();
        uint256 jobId = ++jobCount;
        uint256 deadline = block.timestamp + (durationDays * 86400);
        jobs[jobId] = Job({
            id: jobId, client: msg.sender, provider: provider,
            description: description, budget: budget,
            createdAt: block.timestamp, deadline: deadline,
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

    function submitBid(uint256 jobId, uint256 amount, string calldata proposal) external returns (uint256) {
        Job storage job = jobs[jobId];
        if (job.id == 0) revert JobNotFound();
        if (job.status != JobStatus.Open) revert InvalidStatus();
        if (job.client == msg.sender) revert BidOnOwnJob();

        // Check no duplicate bid
        uint256[] storage existingBids = jobBids[jobId];
        for (uint256 i = 0; i < existingBids.length; i++) {
            if (bids[existingBids[i]].bidder == msg.sender) revert AlreadyBid();
        }

        uint256 bidId = ++bidCount;
        bids[bidId] = Bid({
            jobId: jobId, bidder: msg.sender, amount: amount,
            proposal: proposal, createdAt: block.timestamp, accepted: false
        });

        jobBids[jobId].push(bidId);
        agentBids[msg.sender].push(bidId);

        if (agents[msg.sender].registered) {
            agents[msg.sender].bidsSubmitted++;
        }

        emit BidSubmitted(bidId, jobId, msg.sender, amount);
        return bidId;
    }

    function acceptBid(uint256 bidId) external {
        Bid storage bid = bids[bidId];
        if (bid.jobId == 0) revert BidNotFound();
        Job storage job = jobs[bid.jobId];
        if (job.client != msg.sender) revert NotAuthorized();
        if (job.status != JobStatus.Open) revert InvalidStatus();

        bid.accepted = true;
        job.provider = bid.bidder;
        job.status = JobStatus.Assigned;
        providerJobs[bid.bidder].push(bid.jobId);

        if (agents[bid.bidder].registered) {
            agents[bid.bidder].bidsAccepted++;
        }

        emit BidAccepted(bidId, bid.jobId, bid.bidder);
        emit JobAssigned(bid.jobId, bid.bidder);
    }

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

    function cancelJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        if (job.id == 0) revert JobNotFound();
        if (job.client != msg.sender) revert NotAuthorized();
        if (job.status == JobStatus.Completed) revert InvalidStatus();
        job.status = JobStatus.Cancelled;
        emit JobCancelled(jobId);
    }

    function getJobBids(uint256 jobId) external view returns (uint256[] memory) {
        return jobBids[jobId];
    }

    function getBid(uint256 bidId) external view returns (Bid memory) {
        if (bids[bidId].jobId == 0) revert BidNotFound();
        return bids[bidId];
    }

    function getClientJobs(address client) external view returns (uint256[] memory) {
        return clientJobs[client];
    }

    function getProviderJobs(address provider) external view returns (uint256[] memory) {
        return providerJobs[provider];
    }

    function getJob(uint256 jobId) external view returns (Job memory) {
        if (jobs[jobId].id == 0) revert JobNotFound();
        return jobs[jobId];
    }

    function getAgent(address owner) external view returns (AgentProfile memory) {
        return agents[owner];
    }

    function getStats() external view returns (uint256 totalJobs, uint256 totalAgents, uint256 totalBids) {
        return (jobCount, agentCount, bidCount);
    }
}
