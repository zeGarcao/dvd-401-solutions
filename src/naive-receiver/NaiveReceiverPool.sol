// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {FlashLoanReceiver} from "./FlashLoanReceiver.sol";
import {Multicall} from "./Multicall.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract NaiveReceiverPool is Multicall, IERC3156FlashLender {
    // @audit-info Fixed fee amount for flash loans
    uint256 private constant FIXED_FEE = 1e18; // not the cheapest flash loan
    // @audit-info Data that must be returned by the flash loan callback
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // @audit-info WETH token instance
    WETH public immutable weth;
    // @audit-info Address of the trusted forwarder which can send meta transactions to this contract
    address public immutable trustedForwarder;
    // @audit-info Address of the protocol's fee receiver
    address public immutable feeReceiver;

    // @audit-info Mapping that tracks the balance of each address
    mapping(address => uint256) public deposits;
    // @audit-info Total deposited amount
    // @audit Is this necessary? Couldn't we just use WETH balance?
    uint256 public totalDeposits;

    error RepayFailed();
    error UnsupportedCurrency();
    error CallbackFailed();

    // @audit-ok LGTM
    constructor(address _trustedForwarder, address payable _weth, address _feeReceiver) payable {
        weth = WETH(_weth);
        trustedForwarder = _trustedForwarder;
        feeReceiver = _feeReceiver;
        _deposit(msg.value);
    }

    // @audit-info Function to retrieve the maximum amount that can be borrowed through flash loans
    // @audit-issue Found 1 issue here
    function maxFlashLoan(address token) external view returns (uint256) {
        // @audit-issue We could have a WETH balance > totalDeposits. In this scenario, max flash loan will revert when trying to subract that amount from totalDeposits in flashLoan function
        if (token == address(weth)) return weth.balanceOf(address(this));
        return 0;
    }

    // @audit-info Getter function for flash loan fee
    // @audit-ok LGTM
    function flashFee(address token, uint256) external view returns (uint256) {
        if (token != address(weth)) revert UnsupportedCurrency();
        return FIXED_FEE;
    }

    // @audit-info Function to request flash loans
    // @audit-ok LGTM
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        // @audit-info Reverts if token is not WETH
        if (token != address(weth)) revert UnsupportedCurrency();

        // Transfer WETH and handle control to receiver
        // @audit-info Transfers the requested WETH to the corresponding receiver and decrements the total deposited amount
        weth.transfer(address(receiver), amount);
        totalDeposits -= amount;

        // @audit-info Transfers control to the receiver and reverts in case the receiver didn't returned the correct data
        if (receiver.onFlashLoan(msg.sender, address(weth), amount, FIXED_FEE, data) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }

        // @audit-info Computes the total WETH amount that must be returned by the receiver
        uint256 amountWithFee = amount + FIXED_FEE;
        // @audit-info Transfers the required amount from the receiver to this contract
        weth.transferFrom(address(receiver), address(this), amountWithFee);
        // @audit-info Increments the total WETH deposited
        totalDeposits += amountWithFee;

        // @audit-info Adds the fixed fee amount to the fee receiver's deposit account so that it can be withdrawn later
        deposits[feeReceiver] += FIXED_FEE;

        return true;
    }

    // @audit-info Function to withdraw funds
    // @audit-ok LGTM
    function withdraw(uint256 amount, address payable receiver) external {
        // Reduce deposits
        // @audit-info Updates the caller's deposit account and total deposited amount
        deposits[_msgSender()] -= amount;
        totalDeposits -= amount;

        // Transfer ETH to designated receiver
        weth.transfer(receiver, amount);
    }

    // @audit-info Function to deposit funds
    // @audit-ok LGTM
    function deposit() external payable {
        _deposit(msg.value);
    }

    // @audit-info Internal function to handle deposit business logic
    // @audit-ok LGTM
    function _deposit(uint256 amount) private {
        // @audit-info Wraps sent ETH into WETH
        weth.deposit{value: amount}();

        // @audit-info Updates the caller's deposit account balance and total deposited amount
        deposits[_msgSender()] += amount;
        totalDeposits += amount;
    }

    // @audit-info Function to set the message sender for the current call
    // @audit Noticed something interesting here
    function _msgSender() internal view override returns (address) {
        // @audit-info Caller is last 20 bytes of message data if `msg.sender` is the trusted forwarder, otherwise caller is the regular msg.sender
        // @audit This means that I can arbitrary set the caller through the trusted forwarder?
        if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            return address(bytes20(msg.data[msg.data.length - 20:]));
        } else {
            return super._msgSender();
        }
    }
}
