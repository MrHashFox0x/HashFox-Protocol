// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GovernanceToken.sol"; // Governance token import

contract HashFoxDAO is Ownable(msg.sender) {

    GovernanceToken public governanceToken;
    uint256 public proposalCount;

    uint256 public quorumPercentage = 10; 

    struct Proposal {
        string description;
        uint256 voteCount;
        uint256 endTime;
        bool executed;
        mapping(address => bool) voted;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 indexed proposalId, string description, uint256 endTime);
    event VoteCasted(address indexed voter, uint256 indexed proposalId, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address _governanceToken) {
        governanceToken = GovernanceToken(_governanceToken);
    }

    /// @notice Only HFX members can add proposal
    function createProposal(string memory _description, uint256 _duration) external {
        require(governanceToken.balanceOf(msg.sender) > 0, "You need to have HFX");
        require(_duration > 0, "Duration invalid");

        Proposal storage newProposal = proposals[proposalCount++];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + _duration;

        emit ProposalCreated(proposalCount - 1, _description, newProposal.endTime);
    }

    function getProposalEndTime(uint256 _proposalId) external view returns (uint256) {
    return proposals[_proposalId].endTime;
}



   
    function vote(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp < proposal.endTime, "Vote ended");
        require(!proposal.voted[msg.sender], "Already voted");

        uint256 votingPower = governanceToken.getQuadraticVotingPower(msg.sender);
        require(votingPower > 0, "You need to have HFX token");

        proposal.voteCount += votingPower;  
        proposal.voted[msg.sender] = true;

        emit VoteCasted(msg.sender, _proposalId, votingPower);
    }

    /// @notice Exécute a proposal if quorum is ok
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.endTime, "Vote not ended");
        require(!proposal.executed, "Already executed");

        uint256 quorum = governanceToken.totalSupply() * quorumPercentage / 100;  // Calcul du quorum sans SafeMath
        require(proposal.voteCount >= quorum, "Quorum not reached");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    /// @notice cancel a proposal if not executed yet
    function cancelProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        
        delete proposals[_proposalId];

        emit ProposalCancelled(_proposalId);
    }

    /// @notice Modify quorum
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyOwner {
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");
        quorumPercentage = _quorumPercentage;
    }
}
