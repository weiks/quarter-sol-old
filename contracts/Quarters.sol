pragma solidity ^0.4.16;

interface TokenRecipient {
  function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract Ownable {
  address public owner;

  // Event
  event OwnershipChanged(address indexed oldOwner, address indexed newOwner);

  // Modifier
  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipChanged(owner, newOwner);
    owner = newOwner;
  }
}

contract ERC20 {
  uint256 public totalSupply;
  function balanceOf(address _owner) view public returns (uint256 balance);
  function transfer(address _to, uint256 _value) public returns (bool success);
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
  function approve(address _spender, uint256 _value) public returns (bool success);
  function allowance(address _owner, address _spender) view public returns (uint256 remaining);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

/*  ERC 20 token */
contract StandardToken is ERC20 {
  /**
   * Internal transfer, only can be called by this contract
   */
  function _transfer(address _from, address _to, uint _value) internal returns (bool success) {
    // Prevent transfer to 0x0 address. Use burn() instead
    require(_to != address(0));
    // Check if the sender has enough
    require(balances[_from] >= _value);
    // Check for overflows
    require(balances[_to] + _value > balances[_to]);
    // Save this for an assertion in the future
    uint256 previousBalances = balances[_from] + balances[_to];
    // Subtract from the sender
    balances[_from] -= _value;
    // Add the same to the recipient
    balances[_to] += _value;
    Transfer(_from, _to, _value);
    // Asserts are used to use static analysis to find bugs in your code. They should never fail
    assert(balances[_from] + balances[_to] == previousBalances);

    return true;
  }

  /**
   * Transfer tokens
   *
   * Send `_value` tokens to `_to` from your account
   *
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transfer(address _to, uint256 _value) public returns (bool success) {
    return _transfer(msg.sender, _to, _value);
  }

  /**
   * Transfer tokens from other address
   *
   * Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_value <= allowed[_from][msg.sender]);     // Check allowance
    allowed[_from][msg.sender] -= _value;
    return _transfer(_from, _to, _value);
  }

  function balanceOf(address _owner) view public returns (uint256 balance) {
    return balances[_owner];
  }

  /**
   * Set allowance for other address
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   */
  function approve(address _spender, uint256 _value) public returns (bool success) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  mapping (address => uint256) public balances;
  mapping (address => mapping (address => uint256)) public allowed;
}

contract Quarters is Ownable, StandardToken {
  // Public variables of the token
  string public name = "Quarters";
  string public symbol = "Q";
  uint8 public decimals = 18;

  // ETH/USD rate
  uint16 public ethRate = 300;

  uint256 public price;
  uint256 public tranche = 1000000 * (10 ** 18); // Number of Quarters in initial tranche

  // List of developers
  // address -> status
  mapping (address => bool) public developers;

  uint256 public outstandingQuarters;

  // price values for next cycle
  uint8 public priceNumerator = 2;
  uint8 public priceDenominator = 3;

  // price values for next cycle
  uint8 public trancheNumerator = 2;
  uint8 public trancheDenominator = 1;

  // initial multiples, rates (as percentages) for tiers of developers
  uint32 public mega = 20;
  uint32 public megaRate = 150;
  uint32 public large = 100;
  uint32 public largeRate = 90;
  uint32 public medium = 2000;
  uint32 public mediumRate = 75;
  uint32 public small = 50000;
  uint32 public smallRate = 50;
  uint32 public microRate = 25;

  // ETH rate changed
  event EthRateChanged(uint16 currentRate, uint16 newRate);

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);

  event QuartersOrdered(address sender, uint256 ethValue, uint256 tokens);
  event DeveloperStatusChanged(address developer, bool status);
  event TrancheIncreased(uint256 _tranche, uint256 _price, uint256 etherPool, uint256 _outstandingQuarters);
  event MegaEarnings(uint256 _tranche, uint256 etherPool, uint256 _outstandingQuarters, uint256 _baseRate);
  event Withdraw(uint256 _tranche, uint256 etherPool, uint256 _outstandingQuarters, uint256 _baseRate);

  /**
   * developer modifier
   */
  modifier onlyActiveDeveloper() {
    require(developers[msg.sender] == true);
    _;
  }

  /**
   * Constrctor function
   *
   * Initializes contract with initial supply tokens to the owner of the contract
   */
  function Quarters(
    uint256 initialSupply,
    string tokenName,
    string tokenSymbol,
    uint256 initialPrice,
    uint256 firstTranche
  ) public {
    totalSupply = initialSupply;         // Update total supply with the decimal amount
    balances[msg.sender] = totalSupply; // Give the creator all initial tokens

    name = tokenName;       // Set the name for display purposes
    symbol = tokenSymbol;   // Set the symbol for display purposes
    price = initialPrice;   // initial price
    tranche = firstTranche; // number of Quarters to be sold before increasing price
  }

  function setEthRate (uint16 rate) onlyOwner public {
    // Ether price is set in Wei
    require(rate > 0);
    EthRateChanged(ethRate, rate);
    ethRate = rate;
  }

  /**
   * adjust price for next cycle
   */
  function adjustNextPrice (uint8 numerator, uint8 denominator) onlyOwner public {
    require(numerator > 0 && denominator > 0);
    priceNumerator = numerator;
    priceDenominator = denominator;
  }

  function adjustPrice (uint256 price2) onlyOwner public {
      require(price2 > 0);
      price = price2;
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
    Burn(msg.sender, _value);
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
    totalSupply -= _value;                             // Update totalSupply
    Burn(_from, _value);
    return true;
  }

  /**
   * Buy quarters by sending ethers to contract address (no data required)
   */
  function () payable public {
    buy();
  }

  function buy() payable public {
    uint256 nq = (msg.value * ethRate) * price;
    if (nq > tranche) {
      nq = tranche;
    }

    totalSupply += nq;
    balances[msg.sender] += nq;
    outstandingQuarters += nq;

    if (totalSupply > tranche) {
      // change tranche size for next cycle
      tranche = (tranche * trancheNumerator) / trancheDenominator;

      // change price for next cycle
      price = (price * priceNumerator) / priceDenominator;

      // fire event for tranche change
      TrancheIncreased(tranche, price, this.balance, outstandingQuarters);
    }
    owner.transfer(msg.value / 10);

    // event for quarters order (invoice)
    QuartersOrdered(msg.sender, msg.value, nq);
  }

  function withdraw(uint256 value) onlyActiveDeveloper public {
    require(balances[msg.sender] >= value);
    require(outstandingQuarters > 0);

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
    baseRate = (this.balance - earnings) / (outstandingQuarters + 1);
    if (rate == megaRate) {
      MegaEarnings(tranche, this.balance, outstandingQuarters, baseRate);
    }

    // event for withdraw
    Withdraw(tranche, this.balance, outstandingQuarters, baseRate);

    // earning for developers
    msg.sender.transfer(earnings);
  }

  function getBaseRate () view public returns (uint256) {
    return this.balance / (outstandingQuarters + 1);
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
}
