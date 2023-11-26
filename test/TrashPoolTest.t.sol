// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, console} from "forge-std/Test.sol";
import {TrashPool, LPToken} from "../src/TrashPool.sol";
import {GenericERC20} from "../src/GenericERC20.sol";

contract TrashPoolTest is Test {
    GenericERC20 tokenA;
    GenericERC20 tokenB;
    TrashPool pool;
    LPToken lpToken;


    function setUp() public {
      tokenA = new GenericERC20("Token A", "TKNA", 1e22); // Mock token with a supply
      tokenB = new GenericERC20("Token B", "TKNB", 1e22);
      pool = new TrashPool(address(tokenA), address(tokenB), 0 ether, 0 ether, 30);

      lpToken = LPToken(pool.lpToken());

      tokenA.approve(address(pool), type(uint256).max);
      tokenB.approve(address(pool), type(uint256).max);
    }

    function testAddLiquidity() public {
      uint256 amountA = 1e18; // 1 Token A
      uint256 amountB = 1e18; // 1 Token B

      pool.addLiquidity(amountA, amountB);

      assertEq(tokenA.balanceOf(address(pool)), amountA, "Pool should have Token A");
      assertEq(tokenB.balanceOf(address(pool)), amountB, "Pool should have Token B");
      assertEq(lpToken.balanceOf(address(this)), amountA + amountB, "LP tokens should be minted");
    }

    function testSwapTokens() public {
      // Assuming initial liquidity has been added
      uint256 amountIn = 1e17; // 0.1 Token A
      uint256 expectedOut = pool.calculateSwapAmount(address(tokenA), address(tokenB), amountIn);

      pool.swap(address(tokenA), address(tokenB), amountIn);

      assertEq(tokenB.balanceOf(address(this)), expectedOut, "Should receive correct amount of Token B");
    }

    function testRemoveLiquidity() public {
      // Step 1: Create a new account
      address newUser = vm.addr(1); // Create a new user account

      // Transfer tokens to the new account from the contract's supply
      uint256 amountToTransferA = 100 ether;
      uint256 amountToTransferB = 100 ether;

      // Ensure the contract has enough tokens to transfer
      require(tokenA.balanceOf(address(this)) >= amountToTransferA, "Not enough Token A in contract");
      require(tokenB.balanceOf(address(this)) >= amountToTransferB, "Not enough Token B in contract");

      // Transfer tokens to newUser
      vm.startPrank(address(this)); // Simulate as the contract
      tokenA.transfer(newUser, amountToTransferA);
      tokenB.transfer(newUser, amountToTransferB);
      vm.stopPrank();

      // Step 2: newUser adds liquidity
      vm.startPrank(newUser);
      tokenA.approve(address(pool), amountToTransferA);
      tokenB.approve(address(pool), amountToTransferB);

      pool.addLiquidity(amountToTransferA / 2, amountToTransferB / 2); // Add half of the tokens as liquidity

      // Check LP token balance
      uint256 lpBalance = lpToken.balanceOf(newUser);
      assertTrue(lpBalance > 0, "LP balance should be greater than 0");

      // Step 3: newUser removes liquidity
      lpToken.approve(address(pool), lpBalance);
      pool.takeLiquidity();
      vm.stopPrank(); // Stop simulating transactions from newUser

      // Check final token balances and LP token balance
      uint256 finalBalanceA = tokenA.balanceOf(newUser);
      uint256 finalBalanceB = tokenB.balanceOf(newUser);
      uint256 finalLPBalance = lpToken.balanceOf(newUser);

      assertTrue(finalBalanceA > 0, "User should have Token A after removing liquidity");
      assertTrue(finalBalanceB > 0, "User should have Token B after removing liquidity");
      assertEq(finalLPBalance, 0, "LP balance should be 0 after removing liquidity");
    }
}
