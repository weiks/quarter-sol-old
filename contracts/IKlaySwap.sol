pragma solidity 0.5.6;
interface IKlaySwap {
    
    /**
     * @dev returns pool address based on two address if exists 
     */
    function tokenToPool(address tokenA, address tokenB) external view returns (address);
    
    /**
     * @param tokenA the address of token we are spending
     * @param tokenB the address of token we want
     * @param amountA amount A we want to spend
     * @param amountB minimum amount we want to receive
     * @param path route address
     */
     
    function exchangeKctPos(address tokenA, uint amountA, address tokenB, uint amountB, address[] calldata path) external;
}