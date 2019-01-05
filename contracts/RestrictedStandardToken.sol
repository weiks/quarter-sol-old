pragma solidity ^0.4.18;

import './ERC20.sol';
import './Ownable.sol';

/*  ERC 20 token */
contract RestrictedStandardToken is Ownable, ERC20 {

  event ApprovedStatusChanged(address indexed _address, bool status);

  /**
   * approved modifier
   */
  modifier onlyApproved() {
    require(approved[msg.sender] == true);
    _;
  }

  /**
   * Internal transfer, only can be called by this contract
   */
  function _transfer(address _from, address _to, uint _value) internal returns (bool success) {
    // Prevent transfer to 0x0 address.
    require(_to != address(0));
    // Check if receiver is approved
    require(approved[_from] == true || approved[_to] == true);
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
    emit Transfer(_from, _to, _value);
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
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * Approved status
   */
  function setApprovedStatus (address _address, bool status) onlyOwner public {
    approved[_address] = status;
    emit ApprovedStatusChanged(_address, status);
  }

  mapping (address => bool) public approved;
  mapping (address => uint256) public balances;
  mapping (address => mapping (address => uint256)) public allowed;
}
