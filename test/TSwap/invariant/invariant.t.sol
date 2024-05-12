//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "../../Mocks/ERC20Mock.sol";
import { TSwapPool } from "../../../src/TSwapPool.sol";
import { PoolFactory } from "../../../src/PoolFactory.sol";
import { Handler } from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // these protocol(Pool i mean) have 2 asset's
    ERC20Mock poolToken;
    ERC20Mock weth;

    // we are gonna need to the contract's
    TSwapPool pool;
    PoolFactory factory;
    Handler handler;

    int256 constant STARTING_X = 100e18; // poolToken
    int256 constant STARTING_Y = 50e18; //weth

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));
        handler = new Handler(pool);

        // now create x & y Balance
        poolToken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        // these must approved
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        // Deposit into the Pool
        pool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));

        //
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.deposit.selector;
        selectors[1] = handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
        targetContract(address(handler));
    }

    function invariant_testConstantProductFormulaStaysTheSameX() public {
        assertEq(handler.actuallDeltaX(), handler.expectedDelta_x());
    }

    function invariant_testConstantProductFormulaStaysTheSameY() public {
        assertEq(handler.actualDeltaY(), handler.expectedDelta_y());
    }
}
