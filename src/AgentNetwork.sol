// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NETURION Confidential Agent Network
 * @notice Fairblock IBE ile şifreli multi-agent görev koordinasyonu
 * @dev ERC-8004 inspired confidential agent protocol
 */
contract AgentNetwork {

    enum TaskStatus { Pending, InProgress, Completed, Failed }

    struct Agent {
        address addr;
        string name;
        string capability;
        bool active;
        uint256 tasksCompleted;
    }

    struct Task {
        uint256 id;
        address creator;
        bytes encryptedPayload;
        bytes32 payloadHash;
        uint256 assignedAgent;
        TaskStatus status;
        uint256 createdAt;
        uint256 completedAt;
        bytes encryptedResult;
    }

    Agent[] public agents;
    Task[] public tasks;
    mapping(address => uint256) public agentIndex;
    mapping(address => uint256[]) public agentTasks;
    mapping(address => uint256[]) public creatorTasks;

    event AgentRegistered(uint256 indexed id, address addr, string name);
    event TaskCreated(uint256 indexed id, address creator, uint256 assignedAgent);
    event TaskCompleted(uint256 indexed id, uint256 agentId);
    event TaskFailed(uint256 indexed id, uint256 agentId);

    function registerAgent(string calldata name, string calldata capability) external returns (uint256) {
        uint256 id = agents.length;
        agents.push(Agent({
            addr: msg.sender,
            name: name,
            capability: capability,
            active: true,
            tasksCompleted: 0
        }));
        agentIndex[msg.sender] = id;
        emit AgentRegistered(id, msg.sender, name);
        return id;
    }

    function createTask(
        bytes calldata encryptedPayload,
        bytes32 payloadHash,
        uint256 targetAgent
    ) external returns (uint256) {
        require(targetAgent < agents.length, "Agent not found");
        require(agents[targetAgent].active, "Agent not active");

        uint256 id = tasks.length;
        tasks.push(Task({
            id: id,
            creator: msg.sender,
            encryptedPayload: encryptedPayload,
            payloadHash: payloadHash,
            assignedAgent: targetAgent,
            status: TaskStatus.Pending,
            createdAt: block.timestamp,
            completedAt: 0,
            encryptedResult: ""
        }));
        agentTasks[agents[targetAgent].addr].push(id);
        creatorTasks[msg.sender].push(id);
        emit TaskCreated(id, msg.sender, targetAgent);
        return id;
    }

    function completeTask(uint256 taskId, bytes calldata encryptedResult) external {
        Task storage t = tasks[taskId];
        uint256 agentId = agentIndex[msg.sender];
        require(t.assignedAgent == agentId, "Not assigned agent");
        require(t.status == TaskStatus.Pending || t.status == TaskStatus.InProgress, "Invalid status");
        t.status = TaskStatus.Completed;
        t.completedAt = block.timestamp;
        t.encryptedResult = encryptedResult;
        agents[agentId].tasksCompleted++;
        emit TaskCompleted(taskId, agentId);
    }

    function getAgentCount() external view returns (uint256) { return agents.length; }
    function getTaskCount() external view returns (uint256) { return tasks.length; }
}
