pragma solidity ^0.4.18;
contract IQuarters {
    
  // List of developers
  // address -> status
  mapping (address => bool) public developers;
  /**
   * developer modifier
   */
  modifier onlyActiveDeveloper() {
    require(developers[msg.sender] == true);
    _;
  }

   /**
    * method that will call withdraw method of quarters implementation
    */ 
    function withdraw(uint256 value) onlyActiveDeveloper public;
}