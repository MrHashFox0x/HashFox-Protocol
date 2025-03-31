// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ProjectVault is ERC4626, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");
    bytes32 public constant GUARANTOR_ROLE = keccak256("GUARANTOR_ROLE");

    struct Project {
        uint256 fundingGoal;
        uint256 totalRaised;
        uint256 totalShares;
        bool fundingComplete;
        bool projectFinalized;
        uint256 projectedReturns;
        uint256 loanToValueRatio;
        uint256 liquidationLoanToValueRatio;
        uint256 projectDeadline;
        uint256 collateralDeposited;
        address artist;
        address guarantor;
        AggregatorV3Interface priceFeed;
        mapping(address => uint256) investorShares;
        address[] investors;
    }

    mapping(uint256 => Project) public projects;
    uint256 public nextProjectId;

    event FundsDeposited(uint256 projectId, address indexed investor, uint256 amount);
    event FundsWithdrawn(uint256 projectId, address indexed investor, uint256 amount);
    event FundingComplete(uint256 projectId, uint256 totalRaised);
    event ProjectFinalized(uint256 projectId, uint256 rewardsDistributed);
    event CollateralDeposited(uint256 projectId, address indexed guarantor, uint256 amount);
    event CollateralReleased(uint256 projectId, address indexed guarantor, uint256 amount);
    event CollateralLiquidated(uint256 projectId, address indexed guarantor, uint256 amount);
    event SharesIssued(uint256 projectId, address indexed investor, uint256 shares);

    constructor(IERC20 _stablecoin) ERC4626(_stablecoin) ERC20("Project Vault Share", "PVS") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createProject(
        address _artist,
        uint256 _fundingGoal,
        uint256 _projectedReturns,
        uint256 _loanToValueRatio,
        uint256 _liquidationLoanToValueRatio,
        uint256 _projectDeadline,
        address _priceFeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_artist != address(0), "Artist address required");
        require(_fundingGoal > 0, "Funding goal must be > 0");
        require(_projectedReturns > 0, "Projected returns must be > 0");
        require(_loanToValueRatio > 0 && _loanToValueRatio <= 100, "Invalid LTV ratio");
        require(_liquidationLoanToValueRatio > 0 && _liquidationLoanToValueRatio <= 100, "Invalid LLTV ratio");

        uint256 projectId = nextProjectId++;
        Project storage newProject = projects[projectId];

        newProject.artist = _artist;
        newProject.fundingGoal = _fundingGoal;
        newProject.projectedReturns = _projectedReturns;
        newProject.loanToValueRatio = _loanToValueRatio;
        newProject.liquidationLoanToValueRatio = _liquidationLoanToValueRatio;
        newProject.projectDeadline = _projectDeadline;
        newProject.priceFeed = AggregatorV3Interface(_priceFeed);

        _grantRole(ARTIST_ROLE, _artist);

        emit FundingComplete(projectId, 0);
    }

    function setGuarantor(uint256 projectId, address _guarantor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_guarantor != address(0), "Guarantor address required");
        projects[projectId].guarantor = _guarantor;
        _grantRole(GUARANTOR_ROLE, _guarantor);
    }

    function depositCollateral(uint256 projectId, uint256 amount) external nonReentrant onlyRole(GUARANTOR_ROLE) {
        require(amount > 0, "Collateral must be greater than 0");
        require(projects[projectId].collateralDeposited == 0, "Collateral already deposited");

        uint256 requiredCollateral = (projects[projectId].fundingGoal * 100) / projects[projectId].loanToValueRatio;
        require(amount >= requiredCollateral, "Insufficient collateral amount");

        projects[projectId].collateralDeposited = amount;
        emit CollateralDeposited(projectId, msg.sender, amount);

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
    }

    function invest(uint256 projectId, uint256 amount) external nonReentrant {
        Project storage project = projects[projectId];
        require(!project.fundingComplete, "Funding already complete");
        require(amount > 0, "Investment must be greater than 0");
        require(project.collateralDeposited > 0, "Collateral must be deposited before investment");
        require(project.totalRaised + amount <= project.fundingGoal, "Investment exceeds funding goal");

        deposit(amount, msg.sender);

        uint256 sharesToIssue = previewDeposit(amount);
        project.investorShares[msg.sender] += sharesToIssue;
        project.totalShares += sharesToIssue;
        project.totalRaised += amount;

        addInvestor(projectId, msg.sender);

        emit FundsDeposited(projectId, msg.sender, amount);
        emit SharesIssued(projectId, msg.sender, sharesToIssue);

        if (project.totalRaised >= project.fundingGoal) {
            project.fundingComplete = true;
            emit FundingComplete(projectId, project.totalRaised);

            bool success = IERC20(asset()).safeTransfer(project.artist, project.totalRaised);
            require(success, "Transfer to artist failed");
        }
    }

    function getInvestorShares(uint256 projectId, address investor) external view returns (uint256) {
        return projects[projectId].investorShares[investor];
    }

    function finalizeProject(uint256 projectId, uint256 revenue) external onlyRole(ARTIST_ROLE) nonReentrant {
        Project storage project = projects[projectId];
        require(project.fundingComplete, "Funding not complete");
        require(!project.projectFinalized, "Project already finalized");
        require(revenue >= (project.projectedReturns * 95) / 100, "Revenue below projected returns");

        deposit(revenue, address(this));
        project.projectFinalized = true;
        emit ProjectFinalized(projectId, revenue);
    }

    function withdrawFunds(uint256 projectId) external nonReentrant {
        Project storage project = projects[projectId];
        require(project.projectFinalized, "Project not finalized");
        require(project.investorShares[msg.sender] > 0, "No shares to withdraw");

        uint256 userShares = project.investorShares[msg.sender];
        uint256 shareValue = previewRedeem(userShares);

        project.investorShares[msg.sender] = 0;
        project.totalShares -= userShares;

        withdraw(shareValue, msg.sender, msg.sender);
        emit FundsWithdrawn(projectId, msg.sender, shareValue);
    }

    function handleCollateral(uint256 projectId) external nonReentrant {
        Project storage project = projects[projectId];
        require(block.timestamp > project.projectDeadline, "Deadline not reached");
        require(!project.projectFinalized, "Project already finalized");
        require(hasRole(GUARANTOR_ROLE, msg.sender), "Only guarantor can execute");
        require(project.collateralDeposited > 0, "No collateral to handle");

        uint256 amountToRefund = project.collateralDeposited;
        for (uint i = 0; i < project.investors.length; i++) {
            address investor = project.investors[i];
            uint256 refundAmount = (amountToRefund * project.investorShares[investor]) / project.totalShares;
            IERC20(asset()).safeTransfer(investor, refundAmount);
        }

        project.collateralDeposited = 0;
        emit CollateralReleased(projectId, project.guarantor, amountToRefund);
    }

    function checkAndLiquidate(uint256 projectId) external nonReentrant {
        Project storage project = projects[projectId];
        require(project.collateralDeposited > 0, "No collateral to liquidate");

        (, int price, , , ) = project.priceFeed.latestRoundData();
        require(price > 0, "Invalid price from oracle");

        uint256 collateralValue = uint256(price) * project.collateralDeposited;
        uint256 requiredValue = (project.fundingGoal * project.liquidationLoanToValueRatio) / 100;

        if (collateralValue < requiredValue) {
            uint256 amountToRefund = project.collateralDeposited;
            for (uint i = 0; i < project.investors.length; i++) {
                address investor = project.investors[i];
                uint256 refundAmount = (amountToRefund * project.investorShares[investor]) / project.totalShares;
                IERC20(asset()).safeTransfer(investor, refundAmount);
            }

            project.collateralDeposited = 0;
            emit CollateralLiquidated(projectId, project.guarantor, amountToRefund);
        }
    }

    function addInvestor(uint256 projectId, address _investor) internal {
        Project storage project = projects[projectId];
        project.investors.push(_investor);
    }

    function getInvestors(uint256 projectId) public view returns (address[] memory) {
        return projects[projectId].investors;
    }
}
