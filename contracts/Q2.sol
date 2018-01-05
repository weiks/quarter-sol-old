pragma solidity ^0.4.18;

import './Ownable.sol';
import './StandardToken.sol';

contract Q2 is Ownable, StandardToken {
  string public name = "Q2";
  string public symbol = "Q2";
  uint8 public decimals = 18;

  // token creation cap
  uint256 public creationCap = 15000000 * (10**18); // 15M
  uint256 public reservedFund = 10000000 * (10**18); // 10M

  // events
  event MintTokens(address indexed _to, uint256 _value);
  event StageStarted(uint8 _stage, uint256 _totalSupply, uint256 _balance);
  event StageEnded(uint8 _stage, uint256 _totalSupply, uint256 _balance);

  // eth wallet
  address public ethWallet;

  // current state info
  bool public running;
  uint8 public stage;
  uint256 public exchangeRate;
  uint256 public startBlock;
  uint256 public endBlock;

  function Q2(address _ethWallet) public {
    ethWallet = _ethWallet;

    // reserved tokens
    mintTokens(ethWallet, reservedFund);
  }

  function mintTokens(address to, uint256 value) internal {
    require(value > 0);
    balances[to] += value;
    totalSupply += value;

    require(totalSupply <= creationCap);
    assert(totalSupply >= value);

    MintTokens(to, value);
  }

  function () public payable {
    buyTokens();
  }

  function buyTokens() public payable {
    require(running);
    require(msg.value > 0);
    require(block.number >= startBlock && block.number < endBlock);

    uint256 tokens = msg.value * exchangeRate;
    mintTokens(msg.sender, tokens);
  }

  function startStage(uint256 _exchangeRate, uint256 _startBlock, uint256 _endBlock) public onlyOwner {
    require(!running);
    require(_exchangeRate > 0);
    require(_startBlock > block.number);
    require(_startBlock < _endBlock);

    startBlock = _startBlock;
    endBlock = _endBlock;
    exchangeRate = _exchangeRate;
    stage += 1;
    running = true;

    StageStarted(stage, totalSupply, this.balance);
  }

  function endStage() public onlyOwner {
    require(running);
    require(block.number > endBlock);

    running = false;

    StageEnded(stage, totalSupply, this.balance);
  }

  function withdraw() public onlyOwner {
    ethWallet.transfer(this.balance);
  }
}
