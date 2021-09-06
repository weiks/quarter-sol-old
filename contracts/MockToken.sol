pragma solidity ^0.4.18;

import './StandardToken.sol';

/*
*Used as mock token for testnet
 */
contract MockToken is StandardToken {
   constructor() StandardToken() {
     _mint(msg.sender, 1000 * 10 ** 18);
   }

function _mint(address account, uint256 amount) internal  {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}