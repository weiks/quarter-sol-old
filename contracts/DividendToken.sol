pragma solidity ^0.4.18;

import './SafeMath.sol';
import './ERC20.sol';
import './StandardToken.sol';


/*  Dividend token */
contract DividendToken is StandardToken {
  using SafeMath for uint256;

  struct Account {
    uint256 balance;
    uint256 lastDividendPoint;
  }

  mapping(address => Account) public accounts;
  uint256 public totalDividend;
  uint256 public unclaimedDividend;

  /**
   * Get dividend amount for given account
   *
   * @param account The address for dividend account
   */
  function dividendsOwing(address account) public view returns (uint256) {
    uint256 newDividend = totalDividend.sub(accounts[account].lastDividendPoint);
    return balances[account].mul(newDividend).div(totalSupply);
  }

  /**
   * @dev Update account for dividend
   * @param account The address of owner
   */
  function updateAccount(address account) internal {
    uint256 owing = dividendsOwing(account);
    accounts[account].lastDividendPoint = totalDividend;
    if (owing > 0) {
      unclaimedDividend = unclaimedDividend.sub(owing);
      accounts[account].balance = accounts[account].balance.add(owing);
    }
  }

  function disburse() public payable {
    require(totalSupply > 0);
    require(msg.value > 0);

    uint256 newDividend = msg.value;
    totalDividend = totalDividend.add(newDividend);
    unclaimedDividend = unclaimedDividend.add(newDividend);
  }

  /**
   * @dev Send `_value` tokens to `_to` from your account
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
   * @dev Transfer tokens from other address. Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  ) public returns (bool success) {
    updateAccount(_to);
    updateAccount(_from);
    return super.transferFrom(_from, _to, _value);
  }

  function withdrawDividend() public {
    updateAccount(msg.sender);

    // retrieve dividend amount
    uint256 dividendAmount = accounts[msg.sender].balance;
    require(dividendAmount > 0);
    accounts[msg.sender].balance = 0;

    // transfer dividend amount
    msg.sender.transfer(dividendAmount);
  }
}
