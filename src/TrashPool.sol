// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract TrashPool {
  IERC20 private tokenA;
  IERC20 private tokenB;

  constructor(address _A, address _B, uint256 _a_initial, uint256 _b_initial){
    tokenA = IERC20(_A);
    tokenB = IERC20(_B);

    require(tokenA.transferFrom(msg.sender, address(this), _a_initial), "Transfer of A failed");
    require(tokenB.transferFrom(msg.sender, address(this), _b_initial), "Transfer of B failed");
  }

  function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
      // Validate the tokens are part of the pool
      require((tokenIn == address(tokenA) && tokenOut == address(tokenB)) ||
              (tokenIn == address(tokenB) && tokenOut == address(tokenA)), "Invalid token pair");

      // Calculate the amount of tokenOut to be sent
      uint256 amountOut = calculateSwapAmount(tokenIn, tokenOut, amountIn);

      // Transfer tokenIn from the user to the pool
      require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");

      // Transfer tokenOut from the pool to the user
      require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");

      // ... further logic to maintain the K constant ...
  }
  function calculateSwapAmount(address tokenIn, address tokenOut, uint256 amountIn) private view  returns (uint256) {
    uint256 reserveIn = IERC20(tokenIn).balanceOf(address(this));
    uint256 reserveOut = IERC20(tokenOut).balanceOf(address(this));

    // Calculate K, the constant product
    uint256 K = reserveIn * reserveOut;

    // Calculate new reserves
    uint256 newReserveIn = reserveIn + amountIn;
    uint256 newReserveOut = K / newReserveIn; // rearranged from x * y = K

    // The amount of tokenOut to be sent
    uint256 amountOut = reserveOut - newReserveOut;

    return amountOut;
  }

  function addLiquidity(uint256 desiredDeltaA, uint256 desiredDeltaB) external nonReentrant {
    uint256 reserveA = tokenA.balanceOf(address(this));
    uint256 reserveB = tokenB.balanceOf(address(this));

    uint256 requiredDeltaA = desiredDeltaA;
    uint256 requiredDeltaB = desiredDeltaB;

    if (reserveA > 0 && reserveB > 0) {
        // Calculate the required amounts to maintain K
        requiredDeltaB = (desiredDeltaA * reserveB) / reserveA;
        requiredDeltaA = (desiredDeltaB * reserveA) / reserveB;

        // Ensuring neither of the desired amounts is less than the required amounts
        require(desiredDeltaA >= requiredDeltaA, "Insufficient amount of Token A");
        require(desiredDeltaB >= requiredDeltaB, "Insufficient amount of Token B");
    }

    // Transfer the required amounts from the user to the pool
    require(tokenA.transferFrom(msg.sender, address(this), requiredDeltaA), "Transfer of Token A failed");
    require(tokenB.transferFrom(msg.sender, address(this), requiredDeltaB), "Transfer of Token B failed");
}




}
