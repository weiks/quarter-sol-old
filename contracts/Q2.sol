pragma solidity ^0.4.18;

import './Ownable.sol';
import './DividendToken.sol';

contract Q2 is Ownable, DividendToken {
  string public name = "Q2";
  string public symbol = "Q2";
  uint8 public decimals = 18;

  // token creation cap
  uint256 public creationCap = 15000000 * (10**18); // 15M
  uint256 public reservedFund = 10000000 * (10**18); // 10M

  // stage info
  struct Stage {
    uint8 number;
    uint256 exchangeRate;
    uint256 startBlock;
    uint256 endBlock;
    uint256 cap;
  }

  // events
  event MintTokens(address indexed _to, uint256 _value);
  event StageStarted(uint8 _stage, uint256 _totalSupply, uint256 _balance);
  event StageEnded(uint8 _stage, uint256 _totalSupply, uint256 _balance);

  // eth wallet
  address public ethWallet;
  mapping (uint8 => Stage) stages;

  // current state info
  uint8 public currentStage;

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
    require(msg.value > 0);

    Stage memory stage = stages[currentStage];
    require(block.number >= stage.startBlock && block.number <= stage.endBlock);

    uint256 tokens = msg.value * stage.exchangeRate;
    require(totalSupply + tokens <= stage.cap);

    mintTokens(msg.sender, tokens);
  }

  function startStage(uint256 _exchangeRate, uint256 _cap, uint256 _startBlock, uint256 _endBlock) public onlyOwner {
    require(_exchangeRate > 0 && _cap > 0);
    require(_startBlock > block.number);
    require(_startBlock < _endBlock);

    // check if any stage is running
    Stage memory currentObj = stages[currentStage];
    require(block.number > currentObj.endBlock);

    currentStage += 1;

    // create new stage object
    Stage memory s = Stage({
      number: currentStage,
      startBlock: _startBlock,
      endBlock: _endBlock,
      exchangeRate: _exchangeRate,
      cap: _cap + totalSupply
    });
    stages[currentStage] = s;

    StageStarted(currentStage, totalSupply, this.balance);
  }

  function withdraw() public onlyOwner {
    ethWallet.transfer(this.balance);
  }
}
