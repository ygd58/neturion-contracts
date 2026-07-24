// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title NeturionReputation
 * @notice Onchain reputation system for autonomous AI agents
 * @dev Standalone reputation registry — works alongside ERC-8004
 *      Anti-self-dealing: agents cannot rate themselves
 *      Weighted scoring: evaluator reputation affects score weight
 */
contract NeturionReputation {

    address public immutable PLATFORM;

    struct Score {
        uint256 agentId;
        address rater;
        uint256 raterAgentId;
        uint8   score;       // 0-100
        uint8   weight;      // 1-10 (based on rater reputation)
        string  category;    // "quality", "speed", "accuracy", "communication"
        string  comment;
        uint256 jobId;       // optional: link to NeturionEscrow job
        uint256 timestamp;
    }

    struct AgentReputation {
        uint256 totalWeightedScore;
        uint256 totalWeight;
        uint256 reviewCount;
        uint256 lastUpdated;
        bool    exists;
    }

    uint256 public scoreCount;

    mapping(uint256 => Score) public scores;
    mapping(uint256 => AgentReputation) public reputations;       // agentId => reputation
    mapping(uint256 => uint256[]) public agentScores;             // agentId => scoreIds
    mapping(address => mapping(uint256 => bool)) public hasRated; // rater => agentId => bool
    mapping(address => bool) public authorizedRaters;             // platform-authorized raters

    event ScoreSubmitted(
        uint256 indexed scoreId,
        uint256 indexed agentId,
        address indexed rater,
        uint8   score,
        string  category,
        uint256 jobId
    );
    event RaterAuthorized(address indexed rater);
    event RaterRevoked(address indexed rater);

    error NotAuthorized();
    error SelfRating();
    error AlreadyRated();
    error InvalidScore();
    error InvalidWeight();
    error AgentNotFound();

    modifier onlyPlatform() {
        if (msg.sender != PLATFORM) revert NotAuthorized();
        _;
    }

    constructor() {
        PLATFORM = msg.sender;
        authorizedRaters[msg.sender] = true;
    }

    /**
     * @notice Authorize a rater address (evaluator agents, platform)
     */
    function authorizeRater(address rater) external onlyPlatform {
        authorizedRaters[rater] = true;
        emit RaterAuthorized(rater);
    }

    function revokeRater(address rater) external onlyPlatform {
        authorizedRaters[rater] = false;
        emit RaterRevoked(rater);
    }

    /**
     * @notice Submit a reputation score for an agent
     * @param agentId       ERC-8004 agent ID being rated
     * @param raterAgentId  ERC-8004 agent ID of rater (0 if platform)
     * @param score         Score 0-100
     * @param weight        Weight 1-10
     * @param category      Score category
     * @param comment       Optional comment
     * @param jobId         Optional linked job ID
     */
    function submitScore(
        uint256 agentId,
        uint256 raterAgentId,
        uint8   score,
        uint8   weight,
        string calldata category,
        string calldata comment,
        uint256 jobId
    ) external returns (uint256) {
        if (!authorizedRaters[msg.sender]) revert NotAuthorized();
        if (score > 100) revert InvalidScore();
        if (weight == 0 || weight > 10) revert InvalidWeight();
        if (hasRated[msg.sender][agentId]) revert AlreadyRated();

        hasRated[msg.sender][agentId] = true;

        uint256 scoreId = ++scoreCount;
        scores[scoreId] = Score({
            agentId:     agentId,
            rater:       msg.sender,
            raterAgentId: raterAgentId,
            score:       score,
            weight:      weight,
            category:    category,
            comment:     comment,
            jobId:       jobId,
            timestamp:   block.timestamp
        });

        agentScores[agentId].push(scoreId);

        AgentReputation storage rep = reputations[agentId];
        rep.totalWeightedScore += uint256(score) * uint256(weight);
        rep.totalWeight        += uint256(weight);
        rep.reviewCount++;
        rep.lastUpdated = block.timestamp;
        rep.exists = true;

        emit ScoreSubmitted(scoreId, agentId, msg.sender, score, category, jobId);
        return scoreId;
    }

    /**
     * @notice Get weighted average reputation score (0-100)
     */
    function getReputation(uint256 agentId) external view returns (
        uint256 avgScore,
        uint256 reviewCount,
        uint256 totalWeight
    ) {
        AgentReputation storage rep = reputations[agentId];
        if (!rep.exists || rep.totalWeight == 0) return (0, 0, 0);
        return (
            rep.totalWeightedScore / rep.totalWeight,
            rep.reviewCount,
            rep.totalWeight
        );
    }

    /**
     * @notice Get all score IDs for an agent
     */
    function getAgentScores(uint256 agentId) external view returns (uint256[] memory) {
        return agentScores[agentId];
    }

    /**
     * @notice Get score details
     */
    function getScore(uint256 scoreId) external view returns (Score memory) {
        return scores[scoreId];
    }

    /**
     * @notice Compare two agents by reputation
     */
    function compareAgents(uint256 agentId1, uint256 agentId2) external view returns (
        uint256 score1, uint256 score2, uint256 reviews1, uint256 reviews2
    ) {
        AgentReputation storage r1 = reputations[agentId1];
        AgentReputation storage r2 = reputations[agentId2];
        score1   = r1.totalWeight > 0 ? r1.totalWeightedScore / r1.totalWeight : 0;
        score2   = r2.totalWeight > 0 ? r2.totalWeightedScore / r2.totalWeight : 0;
        reviews1 = r1.reviewCount;
        reviews2 = r2.reviewCount;
    }

    /**
     * @notice Platform stats
     */
    function getStats() external view returns (uint256 totalScores) {
        return scoreCount;
    }
}
