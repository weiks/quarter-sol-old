pragma solidity ^0.5.2;

/*
- Parent contract interface for adding custom logic before calling the 'transfer' function
in the ERC721/ERC20 child chain contract on the Matic chain
- 'transfer' executes the 'beforeTransfer' of this interface contract
- It must follow this interface and return a bool value and
- in case of ERC20 contracts, it should not have 'require' statements and instead return 'false'
- IParentToken contract address in childchain contract can be updated by owner set in rootchain contract only
while mapping new token in rootchain

*/

interface IParentToken {
  function beforeTransfer(address sender, address to, uint256 value) external returns(bool);
}

pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "./IParentToken.sol";

contract ParentTokenMock is IParentToken, Ownable {

  mapping (address => bool) isAllowed;

  function beforeTransfer(address sender, address to, uint256 value) external returns(bool) {
    return isAllowed[sender] || isAllowed[to];
  }

  function updatePermission(address user, bool allowed) public onlyOwner {
    require(user != address(0x0));
    isAllowed[user] = allowed;
  }
}
