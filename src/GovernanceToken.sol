// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract GovernanceToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100M Tokens
    uint256 public constant VESTING_DURATION = 4 * 365 days; // 4 years vesting
    uint256 public immutable launchTime;
    
    address public immutable teamAddress;
    address public immutable investorsAddress;

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
    
    constructor(address _teamAddress, address _investorsAddress) 
        ERC20("HashFox", "HFX") 
        ERC20Permit("HashFox") 
        Ownable(msg.sender) 
    {
        require(_teamAddress != address(0), "Invalid team address");
        require(_investorsAddress != address(0), "Invalid investors address");
        
        teamAddress = _teamAddress;
        investorsAddress = _investorsAddress;
        launchTime = block.timestamp;

        // Initial allocation based on tokenomics
        _mint(msg.sender, MAX_SUPPLY * 30 / 100); // 30% for DAO
        _mint(address(this), MAX_SUPPLY * 25 / 100); // 25% for incentives
        _mint(msg.sender, MAX_SUPPLY * 10 / 100); // 10% Liquidity
        _mint(msg.sender, MAX_SUPPLY * 5 / 100);  // 5% for Airdrop/Partnerships
        _mint(msg.sender, MAX_SUPPLY * 5 / 100);  // 5% for Advisors
        
        // Mint and hold team tokens (15%)
        _mint(address(this), MAX_SUPPLY * 15 / 100);
        vestingSchedules[teamAddress] = Vesting({
            totalAmount: MAX_SUPPLY * 15 / 100,
            claimedAmount: 0,
            startTime: block.timestamp + 365 days // 1 year cliff
        });
        
        // Mint and hold investor tokens (10%)
        _mint(address(this), MAX_SUPPLY * 10 / 100);
        vestingSchedules[investorsAddress] = Vesting({
            totalAmount: MAX_SUPPLY * 10 / 100,
            claimedAmount: 0,
            startTime: block.timestamp + 180 days // 6 months lock-up
        });
    }

    // Vesting function
    function claimVestedTokens() external {
        Vesting storage vesting = vestingSchedules[msg.sender];
        require(vesting.totalAmount > 0, "No vesting available");
        require(block.timestamp >= vesting.startTime, "Vesting not started yet");

        uint256 elapsedTime = block.timestamp - vesting.startTime;
        
        // Cap elapsed time to prevent overflow
        if (elapsedTime > VESTING_DURATION) {
            elapsedTime = VESTING_DURATION;
        }

        uint256 vestedAmount = (vesting.totalAmount * elapsedTime) / VESTING_DURATION;
        uint256 claimable = vestedAmount - vesting.claimedAmount;
        
        require(claimable > 0, "Nothing to claim");

        vesting.claimedAmount += claimable;
        _transfer(address(this), msg.sender, claimable);

        emit TokensVested(msg.sender, claimable);
    }

    // Staking mechanism for governance
    function stake(uint256 amount, uint256 lockTime) external {
        require(amount > 0, "Invalid amount");
        require(lockTime >= 30 days, "Minimum lock time: 30 days");
        
        _transfer(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        lockPeriods[msg.sender] = block.timestamp + lockTime;

        emit TokensStaked(msg.sender, amount);
    }

    function unstake() external {
        require(block.timestamp >= lockPeriods[msg.sender], "Lock period not finished");
        require(stakedBalances[msg.sender] > 0, "Nothing to unstake");

        uint256 amount = stakedBalances[msg.sender];
        stakedBalances[msg.sender] = 0;

        _transfer(address(this), msg.sender, amount);

        emit TokensUnstaked(msg.sender, amount);
    }

    // Token burning mechanism
    function burnTokens(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient funds");
        _burn(msg.sender, amount);

        emit TokensBurned(msg.sender, amount);
    }

    // Quadratic voting system
    function getQuadraticVotingPower(address account) public view returns (uint256) {
        uint256 balance = balanceOf(account);
        uint256 staked = stakedBalances[account];

        return sqrt(balance + staked); // Quadratic voting
    }

    // Square root function for quadratic voting calculation
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

  
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
    return super.nonces(owner);
}

 
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
    


}   
