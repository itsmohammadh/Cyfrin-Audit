//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../../src/TSwapPool.sol";
import { ERC20Mock } from "ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    int256 public expectedDelta_x;
    int256 public expectedDelta_y;
    int256 public starting_x;
    int256 public starting_y;
    int256 public actuallDeltaX;
    int256 public actualDeltaY;

    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(address(pool.getPoolToken()));
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        // uint256 minOutWeth = pool.getMinimumWethDepositAmount();
        outputWeth = bound(outputWeth, pool.getMinimumWethDepositAmount(), weth.balanceOf(address(pool)));
        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }

        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth, poolToken.balanceOf(address(pool)), weth.balanceOf(address(pool))
        );

        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        starting_y = int256(weth.balanceOf(address(pool)));
        starting_x = int256(poolToken.balanceOf(address(pool)));

        expectedDelta_y = int256(-1) * int256(outputWeth);
        expectedDelta_x = int256(poolTokenAmount);

        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(swapper, poolTokenAmount - poolToken.balanceOf(swapper) + 1);
        }

        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        // actual //

        uint256 ending_x = poolToken.balanceOf(address(pool));
        uint256 ending_y = weth.balanceOf(address(pool));

        actualDeltaY = int256(ending_y) - int256(starting_y);
        actuallDeltaX = int256(ending_x) - int256(starting_x);
        // _updateEndingDeltas();
    }

    // deposit, soawpFactoryOutput //

    function deposit(uint256 wethAmountToDeposit) public {
        wethAmountToDeposit = bound(wethAmountToDeposit, pool.getMinimumWethDepositAmount(), type(uint64).max); // 18.446.744.073.709.551.615
        // uint256 amountPoolTokensToDepositBasedOnWeth = pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit);
        // _updateStartingDeltas(int256(wethAmountToDeposit), int256(amountPoolTokensToDepositBasedOnWeth));

        starting_y = int256(weth.balanceOf(address(pool)));
        starting_x = int256(poolToken.balanceOf(address(pool)));

        expectedDelta_y = int256(wethAmountToDeposit);
        expectedDelta_x = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmountToDeposit)); 
            
        // function

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmountToDeposit);
        poolToken.mint(liquidityProvider, uint256(expectedDelta_x));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(wethAmountToDeposit, 0, uint256(expectedDelta_x), uint64(block.timestamp));
        vm.stopPrank();

        // actual //

        uint256 ending_x = poolToken.balanceOf(address(pool));
        uint256 ending_y = weth.balanceOf(address(pool));

        actualDeltaY = int256(ending_y) - int256(starting_y);
        actuallDeltaX = int256(ending_x) - int256(starting_x);
        // _updateEndingDeltas();
    }

    /// Handler supporter :D ///

    // function _updateStartingDeltas(int256 wethAmount, int256 poolTokenAmount) internal {
    //     starting_y = int256(poolToken.balanceOf(address(pool)));
    //     starting_x = int256(weth.balanceOf(address(pool)));

    //     expectedDelta_x = wethAmount;
    //     expectedDelta_y = poolTokenAmount;
    // }

    // function _updateEndingDeltas() internal {
    //     uint256 endingPoolTokenBalance = poolToken.balanceOf(address(pool));
    //     uint256 endingWethBalance = weth.balanceOf(address(pool));

    //     // sell tokens == x == poolTokens
    //     int256 actualDeltaPoolToken = int256(endingPoolTokenBalance) - int256(starting_y);
    //     int256 deltaWeth = int256(endingWethBalance) - int256(starting_x);

    //     actuallDeltaX = deltaWeth;
    //     actualDeltaY = actualDeltaPoolToken;
    // }
}
