// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol)
        Ownable(initialOwner) // Pass the initial owner address to Ownable
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}

contract TrashPool is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;
    uint256 public poolFee;

    //TODO add more logic to keep track of the DEX contract
    constructor(address _A, address _B, uint256 _a_initial, uint256 _b_initial, uint256 _poolFee) {
        tokenA = IERC20(_A);
        tokenB = IERC20(_B);

        poolFee = _poolFee;

        // Construct LP token name and symbol
        string memory lpTokenName = string(abi.encodePacked(ERC20(_A).name(), "-", ERC20(_B).name(), "-RECEIPT"));
        string memory lpTokenSymbol = string(abi.encodePacked("R-", ERC20(_A).symbol(), "-", ERC20(_B).symbol()));

        // Deploy the LP Token with dynamic name and symbol
        lpToken = new LPToken(lpTokenName, lpTokenSymbol, address(this));
        lpToken.transferOwnership(address(this));

        require(tokenA.transferFrom(msg.sender, address(this), _a_initial), "Transfer of A failed");
        require(tokenB.transferFrom(msg.sender, address(this), _b_initial), "Transfer of B failed");

        uint256 initialLPTokens = _a_initial + _b_initial; // Simplified example
        lpToken.mint(msg.sender, initialLPTokens);
    }

    function calculateSwapAmount(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
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

    function calculateSwapReturnWithFee(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256)
    {
        uint256 amountOut = calculateSwapAmount(tokenIn, tokenOut, amountIn);
        uint256 fee = (amountOut * 3) / 1000;
        return amountOut - fee;
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
        // Validate the tokens are part of the pool
        require(
            (tokenIn == address(tokenA) && tokenOut == address(tokenB))
                || (tokenIn == address(tokenB) && tokenOut == address(tokenA)),
            "Invalid token pair"
        );

        // Transfer tokenIn from the user to the pool
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");

        uint256 amountOut = calculateSwapReturnWithFee(tokenIn, tokenOut, amountIn);
        // Transfer tokenOut from the pool to the user
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");
    }

    function totalPoolValue() public view returns (uint256) {
        uint256 reserveA = tokenA.balanceOf(address(this));
        uint256 reserveB = tokenB.balanceOf(address(this));
        // Assuming equal weight or valuation for simplicity
        return reserveA + reserveB;
    }

    function addLiquidity(uint256 desiredDeltaA, uint256 desiredDeltaB) external nonReentrant {
        uint256 reserveA = tokenA.balanceOf(address(this));
        uint256 reserveB = tokenB.balanceOf(address(this));

        uint256 requiredDeltaA = desiredDeltaA;
        uint256 requiredDeltaB = desiredDeltaB;

        if (reserveA > 0 && reserveB > 0) {
            // Calculate the optimal amounts to maintain K
            requiredDeltaB = (desiredDeltaA * reserveB) / reserveA;
            requiredDeltaA = (desiredDeltaB * reserveA) / reserveB;

            // Take the lesser of the desired and required amounts
            if (requiredDeltaB > desiredDeltaB) {
                requiredDeltaB = desiredDeltaB;
                requiredDeltaA = (requiredDeltaB * reserveA) / reserveB;
            } else if (requiredDeltaA > desiredDeltaA) {
                requiredDeltaA = desiredDeltaA;
                requiredDeltaB = (requiredDeltaA * reserveB) / reserveA;
            }
        }

        // Transfer the calculated amounts from the user to the pool
        require(tokenA.transferFrom(msg.sender, address(this), requiredDeltaA), "Transfer of Token A failed");
        require(tokenB.transferFrom(msg.sender, address(this), requiredDeltaB), "Transfer of Token B failed");

        uint256 LPTokensReceipt = requiredDeltaB + requiredDeltaA;
        lpToken.mint(msg.sender, LPTokensReceipt);
    }

    function takeLiquidity() external {
        uint256 LPTotal = lpToken.balanceOf(msg.sender);
        uint256 LPreserveApart = tokenA.balanceOf(address(this)) * (LPTotal / lpToken.totalSupply());
        uint256 LPreserveBpart = tokenB.balanceOf(address(this)) * (LPTotal / lpToken.totalSupply());

        lpToken.burn(msg.sender, LPTotal);
        require(tokenA.transfer(address(this), LPreserveApart), "Transfer of Token A failed");
        require(tokenB.transfer(address(this), LPreserveBpart), "Transfer of Token B failed");
    }
}
