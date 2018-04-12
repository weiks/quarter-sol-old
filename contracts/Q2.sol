pragma solidity ^0.4.18;

import './Ownable.sol';
import './SafeMath.sol';
import './DividendToken.sol';

contract Q2 is Ownable, DividendToken {
  using SafeMath for uint256;

  string public name = "Q2";
  string public symbol = "Q2";
  uint8 public decimals = 18;

  bool public whitelist = true;

  // whitelist addresses
  mapping(address => bool) public whitelistedAddresses;

  // token creation cap
  uint256 public creationCap = 15000000 * (10 ** 18); // 15M
  uint256 public reservedFund = 10000000 * (10 ** 18); // 10M

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
  event WhitelistStatusChanged(address indexed _address, bool status);
  event WhitelistChanged(bool status);

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
    balances[to] = balances[to].add(value);
    totalSupply = totalSupply.add(value);
    require(totalSupply <= creationCap);

    // broadcast event
    MintTokens(to, value);
  }

  function () public payable {
    buyTokens();
  }

  function buyTokens() public payable {
    require(whitelist==false || whitelistedAddresses[msg.sender] == true);
    require(msg.value > 0);

    Stage memory stage = stages[currentStage];
    require(block.number >= stage.startBlock && block.number <= stage.endBlock);

    uint256 tokens = msg.value * stage.exchangeRate;
    require(totalSupply.add(tokens) <= stage.cap);

    mintTokens(msg.sender, tokens);
  }

  function startStage(
    uint256 _exchangeRate,
    uint256 _cap,
    uint256 _startBlock,
    uint256 _endBlock
  ) public onlyOwner {
    require(_exchangeRate > 0 && _cap > 0);
    require(_startBlock > block.number);
    require(_startBlock < _endBlock);

    // stop current stage if it's running
    Stage memory currentObj = stages[currentStage];
    if (currentObj.endBlock > 0) {
      // broadcast stage end event
      StageEnded(currentStage, totalSupply, adddress(this).balance);
    }

    // increment current stage
    currentStage = currentStage + 1;

    // create new stage object
    Stage memory s = Stage({
      number: currentStage,
      startBlock: _startBlock,
      endBlock: _endBlock,
      exchangeRate: _exchangeRate,
      cap: _cap + totalSupply
    });
    stages[currentStage] = s;

    // broadcast stage started event
    StageStarted(currentStage, totalSupply, address(this).balance);
  }

  function withdraw() public onlyOwner {
    ethWallet.transfer(address(this).balance);
  }

  function getCurrentStage() view public returns (
    uint8 number,
    uint256 exchangeRate,
    uint256 startBlock,
    uint256 endBlock,
    uint256 cap
  ) {
    Stage memory currentObj = stages[currentStage];
    number = currentObj.number;
    exchangeRate = currentObj.exchangeRate;
    startBlock = currentObj.startBlock;
    endBlock = currentObj.endBlock;
    cap = currentObj.cap;
  }

  function changeWhitelistStatus(address _address, bool status) public onlyOwner {
    whitelistedAddresses[_address] = status;
    WhitelistStatusChanged(_address, status);
  }
  
  function changeRestrictedtStatus(address _address, bool status) public onlyOwner {
    restrictedAddresses[_address] = status;
    RestrictedStatusChanged(_address, status);
  }
  
  function changeWhitelist(bool status) public onlyOwner {
     whitelist = status;
     WhitelistChanged(status);
  }
}
