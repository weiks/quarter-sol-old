pragma solidity 0.5.6;
interface IExchange {
    function estimatePos(address tokenIn, uint amountIn) external view returns (uint);
}