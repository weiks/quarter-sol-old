pragma solidity ^0.4.18;

import './StandardToken.sol';

/*
*Used as mock token for testnet
 */
contract MockToken is StandardToken {

/**
 * mint the token so that we will approve while buying quarters
 */
function _mint(address account, uint256 amount) internal  {
        require(account != address(0));

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

/**
 * public mint that can be called from outside
 * @param address: address to send the token
 * @param amount : amount to be minted on particular address 
 */
function mint (address account,uint256 amount) public
{
    _mint(account,amount);
}
}