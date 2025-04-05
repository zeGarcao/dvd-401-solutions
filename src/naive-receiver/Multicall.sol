// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

abstract contract Multicall is Context {
    // @audit-info Function to perform multiple calls at once
    // @audit-ok LGTM
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        // @audit-info Loops through the data array and performs each call to address(this) with the corresponding data
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // @audit-info Performs a delegate call to this address with the corresponding data
            //             Pushes the result of the call to the list of results
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}
