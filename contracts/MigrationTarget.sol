pragma solidity 0.5.6;

//
// Migration target
// @dev Implement this interface to make migration target
//
contract MigrationTarget {
  function migrateFrom(address _from, uint256 _amount, uint256 _rewards, uint256 _trueBuy, bool _devStatus) public;
}
