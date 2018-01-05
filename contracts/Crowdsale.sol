pragma solidity ^0.4.18;

contract Crowdsale is Ownable {
  // q2 token object
  Q2 public q2;

  bool public isFinalized;

  address public ethFundDeposit
  uint256 public fundingStartBlock;
  uint256 public fundingEndBlock;

  uint256 public tokenCreationCap = 15000000 * tokenExchangeRate * (10**decimals);

  function Crowdsale(address _token, address _ethFundDeposit, uint256 _fundingStartBlock, uint256 _fundingEndBlock) {
    q2 = Q2(_token);

    ethFundDeposit = _ethFundDeposit;
    fundingStartBlock = _fundingStartBlock;
    fundingEndBlock = _fundingEndBlock;
  }

  function() payable {
    buyTokens();
  }

  /// @dev Ends the funding period and sends the ETH home
  function finalize() external onlyOwner {
    require(!isFinalized);
    require(block.number > fundingEndBlock);

    // move to operational
    isFinalized = true;

    // withdraw ETH amount
    ethFundDeposit.transfer(this.balance));
  }
}
