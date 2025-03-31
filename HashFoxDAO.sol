// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./GovernanceToken.sol"; // Importation du Token de Gouvernance

contract HashFoxDAO is Ownable {
    using SafeMath for uint256;

    GovernanceToken public governanceToken;
    uint256 public proposalCount;

    uint256 public quorumPercentage = 10; // Quorum de 10% de la supply totale des tokens

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

    /// @notice Seuls les détenteurs de HFX peuvent créer une proposition
    function createProposal(string memory _description, uint256 _duration) external {
        require(governanceToken.balanceOf(msg.sender) > 0, "You need to have HFX");
        require(_duration > 0, "Duration invalid");

        Proposal storage newProposal = proposals[proposalCount++];
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + _duration;

        emit ProposalCreated(proposalCount - 1, _description, newProposal.endTime);
    }

    /// @notice Vote basé sur les tokens HFX détenus ou stakés
    function vote(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp < proposal.endTime, "Vote ended");
        require(!proposal.voted[msg.sender], "Already voted");

        uint256 votingPower = governanceToken.getVotingPower(msg.sender);
        require(votingPower > 0, "You need to have HFX token");

        proposal.voteCount = proposal.voteCount.add(votingPower);
        proposal.voted[msg.sender] = true;

        emit VoteCasted(msg.sender, _proposalId, votingPower);
    }

    /// @notice Exécuter une proposition si elle a assez de votes et atteint le quorum
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.endTime, "Vote not ended");
        require(!proposal.executed, "Already executed");

        uint256 quorum = governanceToken.totalSupply().mul(quorumPercentage).div(100); // Quorum en pourcentage des tokens totaux
        require(proposal.voteCount >= quorum, "Quorum not reached");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    /// @notice Annuler une proposition si elle n'a pas encore été exécutée
    function cancelProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        
        delete proposals[_proposalId];

        emit ProposalCancelled(_proposalId);
    }

    /// @notice Permet de modifier le quorum en fonction des besoins
    function setQuorumPercentage(uint256 _quorumPercentage) external onlyOwner {
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");
        quorumPercentage = _quorumPercentage;
    }
}
