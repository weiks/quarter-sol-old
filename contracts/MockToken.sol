pragma solidity 0.5.6;

import './StandardToken.sol';

contract MockToken is StandardToken {
   constructor() StandardToken() public {

   }

function _mint(address account, uint256 amount) internal  {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    
function mint (address account,uint256 amount) public
{
    _mint(account,amount);
}
}