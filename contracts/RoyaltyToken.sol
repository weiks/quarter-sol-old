pragma solidity 0.5.6;

import './SafeMath.sol';
import './ERC20.sol';
import './StandardToken.sol';
import './Ownable.sol';


/*  Royalty token */
contract RoyaltyToken is Ownable, StandardToken {
  using SafeMath for uint256;
  // restricted addresses	
  mapping(address => bool) public restrictedAddresses;
  ERC20 public kusdt = ERC20(0xceE8FAF64bB97a73bb51E115Aa89C17FfA8dD167);
    
  event RestrictedStatusChanged(address indexed _address, bool status);

  struct Account {
    uint256 balance;
    uint256 lastRoyaltyPoint;
  }

  mapping(address => Account) public accounts;
  uint256 public totalRoyalty;
  uint256 public unclaimedRoyalty;

  /**
   * Get Royalty amount for given account
   *
   * @param account The address for Royalty account
   */
  function RoyaltysOwing(address account) public view returns (uint256) {
    uint256 newRoyalty = totalRoyalty.sub(accounts[account].lastRoyaltyPoint);
    return balances[account].mul(newRoyalty).div(totalSupply);
  }

  /**
   * @dev Update account for Royalty
   * @param account The address of owner
   */
  function updateAccount(address account) internal {
    uint256 owing = RoyaltysOwing(account);
    accounts[account].lastRoyaltyPoint = totalRoyalty;
    if (owing > 0) {
      unclaimedRoyalty = unclaimedRoyalty.sub(owing);
      accounts[account].balance = accounts[account].balance.add(owing);
    }
  }

  function disburse(uint256 newRoyalty) public payable {
    require(totalSupply > 0);
    
    totalRoyalty = totalRoyalty.add(newRoyalty);
    unclaimedRoyalty = unclaimedRoyalty.add(newRoyalty);
  }

  /**
   * @dev Send `_value` tokens to `_to` from your account
   *
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transfer(address _to, uint256 _value) public returns (bool success) {
    // Require that the sender is not restricted
    require(restrictedAddresses[msg.sender] == false);
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
  /**
   * Change KUSDT Address if required so that we dont have to redeploy contract
   */
  function changeKUSDT(address kusdtAddress) onlyOwner public
  {
     kusdt = ERC20(kusdtAddress);
  }

  function withdrawRoyalty() public {
      
    updateAccount(msg.sender);

    // retrieve Royalty amount
    uint256 RoyaltyAmount = accounts[msg.sender].balance;
    require(RoyaltyAmount > 0);
    accounts[msg.sender].balance = 0;

    
    // transfer Royalty amount
    kusdt.transfer(msg.sender,kusdt.balanceOf(address(this)));
  }
}
