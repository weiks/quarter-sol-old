pragma solidity 0.5.6;

import './Ownable.sol';
import './ERC20.sol';
import './IPool.sol';

contract Pool is Ownable,IPool
{
    uint256 public exchangeRate  = 10 ** 16;
    
    ERC20 public kusdt = ERC20(0xceE8FAF64bB97a73bb51E115Aa89C17FfA8dD167);
    
    ERC20 public q2 = ERC20(0x8f3c08a7523e76d98F4E3Aa114566afDd93FCCf6);
    
    address masterWallet;
    
    constructor(address wallet) public
    {
        masterWallet = wallet;
    }
    
    function setExchangeRate(uint256 rate) public onlyOwner
    {
       exchangeRate = rate; 
    }
    
    function changeMasterWallet(address newMasterWallet) public onlyOwner
    {
       masterWallet = newMasterWallet; 
    }
    
    function changeKusdtAddress(address newkusdt) public onlyOwner
    {
        kusdt = ERC20(newkusdt);
    }
    
    function changeQ2Address(address newq2) public onlyOwner
    {
        q2 = ERC20(newq2);
    }
    
    /**
     * Exchanging q2 wrt kusdt based on rate from master wallet
     */
    function exchangeQ2withKusdt(uint256 amount) public
    {
        kusdt.transferFrom(msg.sender,address(this),amount);
        uint256 exchangeAmount = amount*exchangeRate;
        q2.transferFrom(masterWallet,msg.sender,exchangeAmount);
    }
    
   function emergencyExit() onlyOwner public
   {
    kusdt.transfer(msg.sender, kusdt.balanceOf(address(this)));
   }
}