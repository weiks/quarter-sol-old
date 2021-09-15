pragma solidity ^0.4.18;

import './StandardToken.sol';

/*
*Used as mock token for testnet
 */
contract MockToken is StandardToken {

function _mint(address account, uint256 amount) internal  {
        require(account != address(0));

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

function mint (address account,uint256 amount) public
{
    _mint(account,amount);
}
}