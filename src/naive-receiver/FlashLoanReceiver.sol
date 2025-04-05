// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {WETH, NaiveReceiverPool} from "./NaiveReceiverPool.sol";

contract FlashLoanReceiver is IERC3156FlashBorrower {
    // @audit-info Address of the pool offering flash loans
    address private pool;

    // @audit-ok LGTM
    constructor(address _pool) {
        pool = _pool;
    }

    // @audit-info Flash loan callback function
    // @audit-issue Found 1 issue here
    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        // @audit-issue Does not check initiator address

        // @audit-info Reverts if the caller is not the pool
        assembly {
            // gas savings
            if iszero(eq(sload(pool.slot), caller())) {
                mstore(0x00, 0x48f5c3ed)
                revert(0x1c, 0x04)
            }
        }

        // @audit-info Reverts if the token is not the WETH
        if (token != address(NaiveReceiverPool(pool).weth())) revert NaiveReceiverPool.UnsupportedCurrency();

        // @audit-info Computes the amount that needs to be repaid
        uint256 amountToBeRepaid;
        unchecked {
            amountToBeRepaid = amount + fee;
        }

        // @audit-info Executes arbitrary action during flash loan
        _executeActionDuringFlashLoan();

        // Return funds to pool
        // @audit-info Approves the pool to pull funds from this contract
        WETH(payable(token)).approve(pool, amountToBeRepaid);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Internal function where the funds received would be used
    function _executeActionDuringFlashLoan() internal {}
}
