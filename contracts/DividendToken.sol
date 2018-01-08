pragma solidity ^0.4.18;

import './ERC20.sol';
import './StandardToken.sol';

/*  Dividend token */
contract DividendToken is StandardToken {
  uint256 public pointMultiplier = 10 ** 18;

  struct Account {
    uint balance;
    uint lastDividendPoint;
  }

  mapping(address => Account) public accounts;
  uint256 public totalDividend;
  uint256 public unclaimedDividend;

  function dividendsOwing(address account) internal view returns (uint256) {
    uint256 newDividend = totalDividend - accounts[account].lastDividendPoint;
    return (accounts[account].balance * newDividend) / totalSupply;
  }

  function updateAccount(address account) public {
    uint256 owing = dividendsOwing(account);
    accounts[account].lastDividendPoint = totalDividend;
    if (owing > 0) {
      unclaimedDividend -= owing;
      accounts[account].balance += owing;
    }
  }

  function disburse() public payable {
    require(totalSupply > 0);
    require(msg.value > 0);

    uint256 newDividend = msg.value;
    totalDividend += newDividend;
    unclaimedDividend += newDividend;
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
    updateAccount(_to);
    updateAccount(msg.sender);
    return super.transfer(_to, _value);
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
    updateAccount(_to);
    updateAccount(_from);
    return super.transferFrom(_from, _to, _value);
  }

  function withdrawDividend() public {
    updateAccount(msg.sender);
    require(accounts[msg.sender].balance > 0);
    msg.sender.transfer(accounts[msg.sender].balance);
    accounts[msg.sender].balance = 0;
  }
}
