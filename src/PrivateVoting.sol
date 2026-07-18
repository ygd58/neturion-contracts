// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title NETURION Private Voting
 * @notice Fairblock IBE ile şifreli oy sistemi
 * @dev Oylar şifreli gönderilir, deadline sonrası reveal edilir
 */
contract PrivateVoting {

    struct Proposal {
        string title;
        string description;
        address creator;
        uint256 deadline;
        bool revealed;
        uint256 yesCount;
        uint256 noCount;
        uint256 totalVotes;
    }

    struct Vote {
        address voter;
        bytes encryptedVote;
        bool revealed;
        bool voteValue;
    }

    Proposal[] public proposals;
    mapping(uint256 => Vote[]) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address creator, string title, uint256 deadline);
    event VoteCast(uint256 indexed proposalId, address voter);
    event VotesRevealed(uint256 indexed proposalId, uint256 yes, uint256 no);

    function createProposal(
        string calldata title,
        string calldata description,
        uint256 durationSeconds
    ) external returns (uint256) {
        uint256 id = proposals.length;
        proposals.push(Proposal({
            title: title,
            description: description,
            creator: msg.sender,
            deadline: block.timestamp + durationSeconds,
            revealed: false,
            yesCount: 0,
            noCount: 0,
            totalVotes: 0
        }));
        emit ProposalCreated(id, msg.sender, title, block.timestamp + durationSeconds);
        return id;
    }

    function castEncryptedVote(uint256 proposalId, bytes calldata encryptedVote) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp < p.deadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        votes[proposalId].push(Vote({
            voter: msg.sender,
            encryptedVote: encryptedVote,
            revealed: false,
            voteValue: false
        }));
        hasVoted[proposalId][msg.sender] = true;
        p.totalVotes++;
        emit VoteCast(proposalId, msg.sender);
    }

    function revealVotes(uint256 proposalId, bool[] calldata voteValues) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.deadline, "Voting still active");
        require(!p.revealed, "Already revealed");
        require(voteValues.length == votes[proposalId].length, "Length mismatch");

        uint256 yes = 0;
        uint256 no = 0;
        for (uint256 i = 0; i < voteValues.length; i++) {
            votes[proposalId][i].revealed = true;
            votes[proposalId][i].voteValue = voteValues[i];
            if (voteValues[i]) yes++;
            else no++;
        }

        p.yesCount = yes;
        p.noCount = no;
        p.revealed = true;
        emit VotesRevealed(proposalId, yes, no);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getVoteCount(uint256 proposalId) external view returns (uint256) {
        return votes[proposalId].length;
    }
}
