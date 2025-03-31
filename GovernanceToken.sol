// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GovernanceToken is ERC20, ERC20Burnable, ERC20Votes, ERC20Permit, Ownable {
    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100M Tokens
    uint256 public constant VESTING_DURATION = 4 * 365 days; // 4 ans de vesting
    uint256 public immutable launchTime;

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
    }

    mapping(address => Vesting) public vestingSchedules;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lockPeriods;

    event TokensVested(address indexed beneficiary, uint256 amount);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    event TokensBurned(address indexed user, uint256 amount);
    
    constructor() ERC20("HashFox", "HFX") ERC20Permit("HashFox") {
        launchTime = block.timestamp;

        // Allocation initiale basée sur la tokenomics
        _mint(msg.sender, MAX_SUPPLY.mul(30).div(100)); // 30% pour la DAO
        _mint(address(this), MAX_SUPPLY.mul(25).div(100)); // 25% pour les incentives (récompenses staking)
        _mint(msg.sender, MAX_SUPPLY.mul(10).div(100)); // 10% Liquidité
        _mint(msg.sender, MAX_SUPPLY.mul(5).div(100)); // 5% pour Airdrop/Partenariats
        _mint(msg.sender, MAX_SUPPLY.mul(5).div(100)); // 5% pour Advisors

        // Vesting pour l'équipe et les investisseurs
        vestingSchedules[msg.sender] = Vesting({
            totalAmount: MAX_SUPPLY.mul(15).div(100),
            claimedAmount: 0,
            startTime: block.timestamp + 365 days // Cliff de 1 an
        });
        vestingSchedules[address(this)] = Vesting({
            totalAmount: MAX_SUPPLY.mul(10).div(100),
            claimedAmount: 0,
            startTime: block.timestamp + 180 days // Vesting investisseur : 6 mois de lock-up
        });
    }

    //  Fonction de vesting
    function claimVestedTokens() external {
        Vesting storage vesting = vestingSchedules[msg.sender];
        require(vesting.totalAmount > 0, "No vesting disponible");

        uint256 elapsedTime = block.timestamp - vesting.startTime;
        require(elapsedTime > 0, "Vesting not started");

        uint256 vestedAmount = (vesting.totalAmount * elapsedTime) / VESTING_DURATION;
        uint256 claimable = vestedAmount - vesting.claimedAmount;
        
        require(claimable > 0, "Nothing to reclaim");

        vesting.claimedAmount += claimable;
        _transfer(address(this), msg.sender, claimable);

        emit TokensVested(msg.sender, claimable);
    }

    //  **Mécanisme de Staking pour la gouvernance**
    function stake(uint256 amount, uint256 lockTime) external {
        require(amount > 0, "Invalid Amount");
        require(lockTime >= 30 days, "Minimum lock time 30 days");
        
        _transfer(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        lockPeriods[msg.sender] = block.timestamp + lockTime;

        emit TokensStaked(msg.sender, amount);
    }

    function unstake() external {
        require(block.timestamp >= lockPeriods[msg.sender], "Locking not finish");
        require(stakedBalances[msg.sender] > 0, "Nothing to unstake");

        uint256 amount = stakedBalances[msg.sender];
        stakedBalances[msg.sender] = 0;

        _transfer(address(this), msg.sender, amount);

        emit TokensUnstaked(msg.sender, amount);
    }

    //  Brûlage des tokens (burn mechanism)
    function burnTokens(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufisant funds");
        _burn(msg.sender, amount);

        emit TokensBurned(msg.sender, amount);
    }

    //  Système de vote Quadratique
    function getVotingPower(address account) public view returns (uint256) {
        uint256 balance = balanceOf(account);
        uint256 staked = stakedBalances[account];

        return (balance + staked).sqrt(); // Quadratic voting
    }

    //  Hooks pour ERC20Votes
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
