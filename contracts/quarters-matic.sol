pragma solidity ^0.4.18;

import './Ownable.sol';
import './RestrictedStandardToken.sol';

interface TokenRecipient {
  function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external;
}

contract Quarters is Ownable, RestrictedStandardToken {
  // Public variables of the token
  string public name = "Quarters";
  string public symbol = "Q";
  uint8 public decimals = 0; // no decimals, only integer quarters

  // List of developers
  // address -> status
  mapping (address => bool) public developers;

  uint256 public outstandingQuarters;
  address public q2;

  // number of Quarters for next tranche
  event QuartersOrdered(address indexed sender, uint256 ethValue, uint256 tokens);
  event DeveloperStatusChanged(address indexed developer, bool status);

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
  ) public {
  }

  /**
   * Developer status
   */
  function setDeveloperStatus (address _address, bool status) onlyOwner public {
    developers[_address] = status;
    emit DeveloperStatusChanged(_address, status);
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
   * Transfer allowance from other address's allowance
   *
   * Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferAllowance(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_value <= allowed[_from][msg.sender]);     // Check allowance
    allowed[_from][msg.sender] -= _value;

    if (_transfer(_from, _to, _value)) {
      // allow msg.sender to spend _to's tokens
      allowed[_to][msg.sender] += _value;
      emit Approval(_to, msg.sender, _value);
      return true;
    }

    return false;
  }
