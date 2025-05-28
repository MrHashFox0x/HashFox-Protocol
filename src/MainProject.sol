// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Vault.sol";  

contract MainProject is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");
    bytes32 public constant GUARANTOR_ROLE = keccak256("GUARANTOR_ROLE");

    struct Project {
        address artist;
        address vault;
        uint256 fundingGoal;
        uint256 projectedReturns;
        uint256 loanToValueRatio;
        uint256 projectDeadline;
        bool isActive;
    }

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    event ProjectCreated(uint256 indexed projectId, address indexed artist, address vault);
    event InvestmentMade(uint256 indexed projectId, address indexed investor, uint256 amount);
    event FundsWithdrawn(uint256 indexed projectId, address indexed investor, uint256 amount);
    event CollateralDeposited(uint256 indexed projectId, address indexed guarantor, uint256 amount);
    event CollateralReleased(uint256 indexed projectId, address indexed guarantor, uint256 amount);
    event ProjectFinalized(uint256 indexed projectId, uint256 revenue);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     
     */
    function createProject(
        address _artist,
        uint256 _fundingGoal,
        uint256 _projectedReturns,
        uint256 _loanToValueRatio,
        uint256 _liquidationLoanToValueRatio,
        uint256 _projectDeadline,
        address _stablecoin,   
        address _priceFeed
    ) external onlyRole(ADMIN_ROLE) {
        require(_artist != address(0), "Artist address required");
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        require(_projectedReturns > 0, "Projected returns must be greater than 0");
        require(_loanToValueRatio > 0 && _loanToValueRatio <= 100, "Invalid loan to value ratio");
        require(_liquidationLoanToValueRatio > 0 && _liquidationLoanToValueRatio <= 100, "Invalid LLTV");

       
        Vault vault = new Vault(
            IERC20(_stablecoin)
        );
        
        vault.createProject(_artist, _fundingGoal, _projectedReturns, _loanToValueRatio, _liquidationLoanToValueRatio, _projectDeadline, _priceFeed);
       
        // Enregistrement du projet
        projectCount++;
        projects[projectCount] = Project({
            artist: _artist,
            vault: address(vault),
            fundingGoal: _fundingGoal,
            projectedReturns: _projectedReturns,
            loanToValueRatio: _loanToValueRatio,
            projectDeadline: _projectDeadline,
            isActive: true
        });

        emit ProjectCreated(projectCount, _artist, address(vault));
    }

    /**
     * @dev Permet à un investisseur d'investir dans un projet.
     */
    function invest(uint256 projectId, uint256 amount) external {
        Project storage project = projects[projectId];
        require(project.isActive, "Project is not active");
        require(amount > 0, "Investment must be greater than 0");

        Vault vault = Vault(project.vault);
        vault.invest(projectId, amount);

        emit InvestmentMade(projectId, msg.sender, amount);
    }

    /**
     * @dev Finaliser un projet en distribuant les rendements aux investisseurs.
     */
    function finalizeProject(uint256 projectId, uint256 revenue) external onlyRole(ARTIST_ROLE) {
        Project storage project = projects[projectId];
        require(project.isActive, "Project is not active");
        require(msg.sender == project.artist, "Only artist can finalize project");

        Vault vault = Vault(project.vault);
        vault.finalizeProject(projectId, revenue);

        project.isActive = false;
        emit ProjectFinalized(projectId, revenue);
    }

    /**
     * @dev Permet à un investisseur de retirer ses fonds après la finalisation du projet.
     */
    function withdrawFunds(uint256 projectId) external {
        Project storage project = projects[projectId];
        require(!project.isActive, "Project is still active");

        Vault vault = Vault(project.vault);
        uint256 shares = vault.getInvestorShares(projectId, msg.sender);
        uint256 amount = vault.previewRedeem(shares);

        vault.withdrawFunds(projectId);

        emit FundsWithdrawn(projectId, msg.sender, amount);
    }

    /**
     * @dev Activer ou désactiver un projet (administration).
     */
    function toggleProjectStatus(uint256 projectId, bool status) external onlyRole(ADMIN_ROLE) {
        projects[projectId].isActive = status;
    }

    /**
     * @dev Permet au garant de déposer un collatéral pour un projet.
     */
    function depositCollateral(uint256 projectId, uint256 amount) external onlyRole(GUARANTOR_ROLE) {
        Project storage project = projects[projectId];
        require(project.isActive, "Project is not active");

        Vault vault = Vault(project.vault);
        vault.depositCollateral(projectId, amount);

        emit CollateralDeposited(projectId, msg.sender, amount);
    }

    /**
     * @dev Permet au garant de gérer le collatéral après la finalisation du projet.
     */
    function handleCollateral(uint256 projectId) external onlyRole(GUARANTOR_ROLE) {
        Project storage project = projects[projectId];
        require(!project.isActive, "Project is still active");

        Vault vault = Vault(project.vault);
        uint256 collateralAmount = vault.returnCollateral(projectId);

        vault.handleCollateral(projectId);

        emit CollateralReleased(projectId, msg.sender, collateralAmount);
    }
}
