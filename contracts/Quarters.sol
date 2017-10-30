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
  function _transfer(address _from, address _to, uint _value) internal {
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
    _transfer(msg.sender, _to, _value);
		return true;
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
    _transfer(_from, _to, _value);
    return true;
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
  string public name;
  string public symbol;
  uint8 public decimals = 18;

  // 18 decimals is the strongly suggested default, avoid changing it
  uint256 public price;
  uint256 public tranche;

  uint256 public outstandingQuarters;
  uint256 public baseRate = 1;

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);

  event TrancheIncrease(uint256 _tranche, uint256 _price, uint256 etherPool, uint256 _outstandingQuarters);
  event MegaEarnings(uint256 _tranche, uint256 etherPool, uint256 _outstandingQuarters, uint256 _baseRate);

  /**
  * Constrctor function
  *
  * Initializes contract with initial supply tokens to the owner of the contract
  */
  function TokenERC20(
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

  function buy() payable public {
    uint256 nq = msg.value*300/price/1000000000000000;    // 300 is a placeholder for the Ether/USD exchange rate
    if (nq > tranche) {
      nq = tranche;
    }
    totalSupply = totalSupply + nq;
    balances[msg.sender] = balances[msg.sender] + nq;
    outstandingQuarters+=nq;
    baseRate = this.balance/(outstandingQuarters+1);
    if (totalSupply>tranche) {
      tranche = 2*tranche;   // magic number: tranche size
      price = price * 3 /2;   // magic number: price increase number
      TrancheIncrease( tranche,  price,  this.balance, outstandingQuarters);
    }
    owner.transfer(msg.value/10);
  }

  // what happens when totalSupply reaches maximum --> let the totalSupply, tranche & price increase rate be settable by the owner

  // what happens if price gets too low?

  // creating the economic flow in the ethereum
  // gaming community -- token for the games, dice game,

  function withdraw(uint256 _value) public {
    // ** check if developer
    uint256 n = _value;
    if (n > balances[msg.sender]) {      // can only request to redeem Quarters that you have
      n = balances[msg.sender];
    }
    balances[msg.sender] -= n;
    uint256 earnings = n*baseRate;
    uint256 rate = 25;          // else, rate for micro developer
    if (n*20 > tranche) {       // size of mega developer
      rate = 150;           // rate for mega developer
    } else if (n*100 > tranche) {   // size & rate for large developer
      rate = 90;
    } else if (n*2000 > tranche) {  // size and rate for medium developer
      rate = 75;
    } else if (n*50000 > tranche){  // size and rate for small developer
      rate=50;
    }

    if (rate * earnings / 100 > this.balance) {
      earnings = this.balance;
    } else {
      earnings = rate*earnings/100;
    }

    outstandingQuarters -= n;        // update the outstanding Quarters
    baseRate = (this.balance-earnings) / (outstandingQuarters+1);
    if (rate == 150) {
      MegaEarnings(tranche, this.balance, outstandingQuarters, baseRate);
    }
    msg.sender.transfer(earnings);  // get your earnings!
  }
}
