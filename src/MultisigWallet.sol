// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./HashFoxDAO.sol"; // DAO import

contract MultiSigWallet is Ownable(msg.sender) {

    uint256 public requiredSignatures;
    address[] public signers;
    mapping(address => bool) public isSigner;
    mapping(uint256 => mapping(address => bool)) public proposalSignatures;
    
    HashFoxDAO public hashFoxDAO;

    event ProposalSigned(address indexed signer, uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }

    constructor(address[] memory _signers, uint256 _requiredSignatures, address _hashFoxDAO) {
        require(_signers.length > 0, "At least one signer required");
        require(_requiredSignatures <= _signers.length, "Invalid required signatures count");

        for (uint256 i = 0; i < _signers.length; i++) {
            require(!isSigner[_signers[i]], "Signer address already added");
            isSigner[_signers[i]] = true;
            signers.push(_signers[i]);
        }
        requiredSignatures = _requiredSignatures;
        hashFoxDAO = HashFoxDAO(_hashFoxDAO);
    }

   
    function signProposal(uint256 _proposalId) external onlySigner {
        require(!proposalSignatures[_proposalId][msg.sender], "Signer already voted");
        require(block.timestamp < hashFoxDAO.getProposalEndTime(_proposalId), "Voting ended");

    

        proposalSignatures[_proposalId][msg.sender] = true;
        emit ProposalSigned(msg.sender, _proposalId);
    }

   
    function executeProposal(uint256 _proposalId) external onlySigner {
        require(block.timestamp >= hashFoxDAO.getProposalEndTime(_proposalId), "Vote not ended");
        
        uint256 signedCount = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            if (proposalSignatures[_proposalId][signers[i]]) {
                signedCount += 1;
            }
        }

        require(signedCount >= requiredSignatures, "Not enough signatures");

        // Si suffisamment de signatures, on exécute la proposition de la DAO
        hashFoxDAO.executeProposal(_proposalId);
        emit ProposalExecuted(_proposalId);
    }

   
    function setRequiredSignatures(uint256 _requiredSignatures) external onlyOwner {
        require(_requiredSignatures <= signers.length, "Invalid required signatures count");
        requiredSignatures = _requiredSignatures;
    }
}

