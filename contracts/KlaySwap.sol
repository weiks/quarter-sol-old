pragma solidity 0.5.6;

import './IKlaySwap.sol';
import './IExchange.sol';
import './ERC20.sol';
import './Ownable.sol';

contract KlaySwap is Ownable{
    
    /**
     * Factory Address involved in token Swap
     */ 
    address public FACTORY_ADDRESS = 0xC6a2Ad8cC6e4A7E08FC37cC5954be07d499E7654;
    
    IKlaySwap factory = IKlaySwap(FACTORY_ADDRESS);
    
    /**
     * @dev estimate amount of token to be returned when spending amountIn Amount of address tokenIn
     * @param tokenIn address of token we are spending
     * @param tokenOut address of token we are expecting
     * @param amountIn amount of tokenA we are spending
     */
     
    function estimatePos(address tokenIn, address tokenOut, uint amountIn, address[] memory path) public view returns (uint amountOut){
        IExchange exchange;
        for(uint i = 0; i < path.length; i++){
            exchange = IExchange(factory.tokenToPool(tokenIn, path[i]));
            amountIn = exchange.estimatePos(tokenIn, amountIn);
            tokenIn = path[i];
        }
        exchange = IExchange(factory.tokenToPool(tokenIn, tokenOut));
        amountOut = exchange.estimatePos(tokenIn, amountIn);
        return amountOut;
    }
    
    /**
     * exchange tokenA with tokenB with (tokenA,tokenB) pool
     * @param tokenA address of token we are spending
     * @param tokenB address of token we are expecting
     * @param amountA amount of tokenA we are spending 
     */ 
     
    function exchangeKctPos(address tokenA, uint256 amountA, address tokenB, address[] memory path) public {
      /**
       * @dev Sending Token from user wallet to our contract 
       */ 
      ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
      
      /**
       * @dev Approving routerAddress to spend token
       */ 
      ERC20(tokenA).approve(FACTORY_ADDRESS, amountA);
      
      /**
       * @dev Exchanging tokenA with tokenB
       */ 
      factory.exchangeKctPos(tokenA, amountA, tokenB, estimatePos(tokenA,tokenB,amountA,path), path);
    }
    
    /**
     * @dev Changing router address
     * 
     */ 
    function changeRouter(address routerAddress) public onlyOwner
    {
      FACTORY_ADDRESS = routerAddress;
    }
    
}
