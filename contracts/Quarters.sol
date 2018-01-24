pragma solidity ^0.4.18;

import './Ownable.sol';
import './StandardToken.sol';
import './Q2.sol';
import './MigrationTarget.sol';

interface TokenRecipient {
  function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract Quarters is Ownable, StandardToken {
  // Public variables of the token
  string public name = "Quarters";
  string public symbol = "Q";
  uint8 public decimals = 0; // no decimals, only integer quarters

  uint16 public ethRate = 4000; // Quarters/ETH
  uint256 public tranche = 40000; // Number of Quarters in initial tranche

  // List of developers
  // address -> status
  mapping (address => bool) public developers;

  uint256 public outstandingQuarters;
  address public q2;

  // number of Quarters for next tranche
  uint8 public trancheNumerator = 2;
  uint8 public trancheDenominator = 1;

  // initial multiples, rates (as percentages) for tiers of developers
  uint32 public mega = 20;
  uint32 public megaRate = 115;
  uint32 public large = 100;
  uint32 public largeRate = 90;
  uint32 public medium = 2000;
  uint32 public mediumRate = 75;
  uint32 public small = 50000;
  uint32 public smallRate = 50;
  uint32 public microRate = 25;

  // rewards related storage
  mapping (address => uint256) public rewards;    // rewards earned, but not yet collected
  mapping (address => uint256) public trueBuy;    // tranche rewards are set based on *actual* purchases of Quarters

  uint256 public rewardAmount = 40;

  uint8 public rewardNumerator = 1;
  uint8 public rewardDenominator = 4;

  // reserve ETH from Q2 to fund rewards
  uint256 public reserveETH=0;

  // ETH rate changed
  event EthRateChanged(uint16 currentRate, uint16 newRate);

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);

  event QuartersOrdered(address indexed sender, uint256 ethValue, uint256 tokens);
  event DeveloperStatusChanged(address indexed developer, bool status);
  event TrancheIncreased(uint256 _tranche, uint256 _etherPool, uint256 _outstandingQuarters);
  event MegaEarnings(address indexed developer, uint256 value, uint256 _baseRate, uint256 _tranche, uint256 _outstandingQuarters, uint256 _etherPool);
  event Withdraw(address indexed developer, uint256 value, uint256 _baseRate, uint256 _tranche, uint256 _outstandingQuarters, uint256 _etherPool);
  event BaseRateChanged(uint256 _baseRate, uint256 _tranche, uint256 _outstandingQuarters, uint256 _etherPool,  uint256 _totalSupply);
  event Reward(address indexed _address, uint256 value, uint256 _outstandingQuarters, uint256 _totalSupply);

  /**
   * developer modifier
   */
  modifier onlyActiveDeveloper() {
    require(developers[msg.sender] == true);
    _;
  }

  /**
   * Constructor function
   *
   * Initializes contract with initial supply tokens to the owner of the contract
   */
  function Quarters(
    address _q2,
    uint256 firstTranche
  ) public {
    q2 = _q2;
    tranche = firstTranche; // number of Quarters to be sold before increasing price
  }

  function setEthRate (uint16 rate) onlyOwner public {
    // Ether price is set in Wei
    require(rate > 0);
    EthRateChanged(ethRate, rate);
    ethRate = rate;
  }

  /**
   * Adjust reward amount
   */
  function adjustReward (uint256 reward) onlyOwner public {
    rewardAmount = reward; // may be zero, no need to check value to 0
  }

  function adjustWithdrawRate(uint32 mega2, uint32 megaRate2, uint32 large2, uint32 largeRate2, uint32 medium2, uint32 mediumRate2, uint32 small2, uint32 smallRate2, uint32 microRate2) onlyOwner public {
    // the values (mega, large, medium, small) are multiples, e.g., 20x, 100x, 10000x
    // the rates (megaRate, etc.) are percentage points, e.g., 150 is 150% of the remaining etherPool
    if (mega2 > 0 && megaRate2 > 0) {
      mega = mega2;
      megaRate = megaRate2;
    }

    if (large2 > 0 && largeRate2 > 0) {
      large = large2;
      largeRate = largeRate2;
    }

    if (medium2 > 0 && mediumRate2 > 0) {
      medium = medium2;
      mediumRate = mediumRate2;
    }

    if (small2 > 0 && smallRate2 > 0){
      small = small2;
      smallRate = smallRate2;
    }

    if (microRate2 > 0) {
      microRate = microRate2;
    }
  }

  /**
   * adjust tranche for next cycle
   */
  function adjustNextTranche (uint8 numerator, uint8 denominator) onlyOwner public {
    require(numerator > 0 && denominator > 0);
    trancheNumerator = numerator;
    trancheDenominator = denominator;
  }

  function adjustTranche(uint256 tranche2) onlyOwner public {
    require(tranche2 > 0);
    tranche = tranche2;
  }

  /**
   * Adjust rewards for `_address`
   */
  function updatePlayerRewards(address _address) internal {
    require(_address != address(0));

    uint256 _reward = 0;
    if (rewards[_address] == 0) {
      _reward = rewardAmount;
    } else if (rewards[_address] < tranche) {
      _reward = trueBuy[_address] * rewardNumerator / rewardDenominator;
    }

    if (_reward > 0) {
      // update rewards record
      rewards[_address] = tranche;

      balances[_address] += _reward;
      allowed[_address][msg.sender] += _reward; // set allowance
      Approval(_address, msg.sender, _reward);

      totalSupply += _reward;
      outstandingQuarters += _reward;

      uint256 spentETH = (_reward * (10 ** 18)) / ethRate;
      if (reserveETH >= spentETH) {
          reserveETH -= spentETH;
        } else {
          reserveETH = 0;
        }

      // tranche size change
      _changeTrancheIfNeeded();

      // reward event
      Reward(_address, _reward, outstandingQuarters, totalSupply);
    }
  }

  /**
   * Developer status
   */
  function setDeveloperStatus (address _address, bool status) onlyOwner public {
    developers[_address] = status;
    DeveloperStatusChanged(_address, status);
  }

  /**
   * Set allowance for other address and notify
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   * @param _extraData some extra information to send to the approved contract
   */
  function approveAndCall(address _spender, uint256 _value, bytes _extraData)
  public
  returns (bool success) {
    TokenRecipient spender = TokenRecipient(_spender);
    if (approve(_spender, _value)) {
      spender.receiveApproval(msg.sender, _value, this, _extraData);
      return true;
    }

    return false;
  }

  /**
   * Destroy tokens
   *
   * Remove `_value` tokens from the system irreversibly
   *
   * @param _value the amount of money to burn
   */
  function burn(uint256 _value) public returns (bool success) {
    require(balances[msg.sender] >= _value);   // Check if the sender has enough
    balances[msg.sender] -= _value;            // Subtract from the sender
    totalSupply -= _value;                     // Updates totalSupply
    outstandingQuarters -= _value;              // Update outstanding quarters
    Burn(msg.sender, _value);

    // log rate change
    BaseRateChanged(getBaseRate(), tranche, outstandingQuarters, this.balance, totalSupply);
    return true;
  }

  /**
   * Destroy tokens from other account
   *
   * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
   *
   * @param _from the address of the sender
   * @param _value the amount of money to burn
   */
  function burnFrom(address _from, uint256 _value) public returns (bool success) {
    require(balances[_from] >= _value);                // Check if the targeted balance is enough
    require(_value <= allowed[_from][msg.sender]);     // Check allowance
    balances[_from] -= _value;                         // Subtract from the targeted balance
    allowed[_from][msg.sender] -= _value;              // Subtract from the sender's allowance
    totalSupply -= _value;                      // Update totalSupply
    outstandingQuarters -= _value;              // Update outstanding quarters
    Burn(_from, _value);

    // log rate change
    BaseRateChanged(getBaseRate(), tranche, outstandingQuarters, this.balance, totalSupply);
    return true;
  }

  /**
   * Buy quarters by sending ethers to contract address (no data required)
   */
  function () payable public {
    _buy(msg.sender);
  }

  function buy() payable public {
    _buy(msg.sender);
  }

  function buyFor(address buyer) payable public {
    uint256 _value =  _buy(buyer);

    // allow donor (msg.sender) to spend buyer's tokens
    allowed[buyer][msg.sender] += _value;
    Approval(buyer, msg.sender, _value);
  }

  function _changeTrancheIfNeeded() internal {
    if (totalSupply >= tranche) {
      // change tranche size for next cycle
      tranche = (tranche * trancheNumerator) / trancheDenominator;

      // fire event for tranche change
      TrancheIncreased(tranche, this.balance, outstandingQuarters);
    }
  }

  // returns number of quarters buyer got
  function _buy(address buyer) internal returns (uint256) {
    require(buyer != address(0));

    uint256 nq = (msg.value * ethRate) / (10 ** 18);
    require(nq != 0);
    if (nq > tranche) {
      nq = tranche;
    }

    totalSupply += nq;
    balances[buyer] += nq;
    trueBuy[buyer] += nq;
    outstandingQuarters += nq;

    // change tranche size
    _changeTrancheIfNeeded();

    // transfer owner's cut
    Q2(q2).disburse.value(msg.value * 15 / 100)();

    // event for quarters order (invoice)
    QuartersOrdered(buyer, msg.value, nq);

    // log rate change
    BaseRateChanged(getBaseRate(), tranche, outstandingQuarters, this.balance, totalSupply);

    // return nq
    return nq;
  }

  /**
   * Transfer allowance from other address's allowance
   *
   * Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferAllowance(address _from, address _to, uint256 _value) public returns (bool success) {
    updatePlayerRewards(_from);
    require(_value <= allowed[_from][msg.sender]);     // Check allowance
    allowed[_from][msg.sender] -= _value;

    if (_transfer(_from, _to, _value)) {
      // allow msg.sender to spend _to's tokens
      allowed[_to][msg.sender] += _value;
      Approval(_to, msg.sender, _value);
      return true;
    }

    return false;
  }

  function withdraw(uint256 value) onlyActiveDeveloper public {
    require(balances[msg.sender] >= value);

    uint256 baseRate = getBaseRate();
    require(baseRate > 0); // check if base rate > 0

    uint256 earnings = value * baseRate;
    uint256 rate = getRate(value); // get rate from value and tranche
    uint256 earningsWithBonus = (rate * earnings) / 100;
    if (earningsWithBonus > this.balance) {
      earnings = this.balance;
    } else {
      earnings = earningsWithBonus;
    }

    balances[msg.sender] -= value;
    outstandingQuarters -= value; // update the outstanding Quarters

    uint256 etherPool = this.balance - earnings;
    if (rate == megaRate) {
      MegaEarnings(msg.sender, earnings, baseRate, tranche, outstandingQuarters, etherPool); // with current base rate
    }

    // event for withdraw
    Withdraw(msg.sender, earnings, baseRate, tranche, outstandingQuarters, etherPool);  // with current base rate

    // earning for developers
    msg.sender.transfer(earnings);

    // log rate change
    BaseRateChanged(getBaseRate(), tranche, outstandingQuarters, this.balance, totalSupply);
  }

  function disburse() public payable {
    reserveETH += msg.value;
  }

  function getBaseRate () view public returns (uint256) {
    if (outstandingQuarters > 0) {
      return (this.balance - reserveETH) / outstandingQuarters;
    }

    return (this.balance - reserveETH);
  }

  function getRate (uint256 value) view public returns (uint32) {
    if (value * mega > tranche) {  // size & rate for mega developer
      return megaRate;
    } else if (value * large > tranche) {   // size & rate for large developer
      return largeRate;
    } else if (value * medium > tranche) {  // size and rate for medium developer
      return mediumRate;
    } else if (value * small > tranche){  // size and rate for small developer
      return smallRate;
    }

    return microRate; // rate for micro developer
  }


  //
  // Migrations
  //

  // Target contract
  address public migrationTarget;
  bool public migrating = false;

  // Migrate event
  event Migrate(address indexed _from, uint256 _value);

  //
  // Migrate tokens to the new token contract.
  //
  function migrate() public {
    require(migrationTarget != address(0));
    uint256 _amount = balances[msg.sender];
    require(_amount > 0);
    balances[msg.sender] = 0;

    totalSupply = totalSupply - _amount;
    outstandingQuarters = outstandingQuarters - _amount;
    MigrationTarget(migrationTarget).migrateFrom(msg.sender, _amount, rewards[msg.sender], trueBuy[msg.sender], developers[msg.sender]);
    Migrate(msg.sender, _amount);

    rewards[msg.sender] = 0;
    trueBuy[msg.sender] = 0;
    developers[msg.sender] = false;
  }

  //
  // Set address of migration target contract
  // @param _target The address of the MigrationTarget contract
  //
  function setMigrationTarget(address _target) onlyOwner public {
    migrationTarget = _target;
  }
}
