// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {console} from "forge-std/Test.sol";

interface IHasTrustedForwarder {
    function trustedForwarder() external view returns (address);
}

contract BasicForwarder is EIP712 {
    struct Request {
        address from;
        address target;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
        uint256 deadline;
    }

    error InvalidSigner();
    error InvalidNonce();
    error OldRequest();
    error InvalidTarget();
    error InvalidValue();

    // @audit-info Bytes representation of the request data structure
    bytes32 private constant _REQUEST_TYPEHASH = keccak256(
        "Request(address from,address target,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 deadline)"
    );

    // @audit-info Mapping that tracks request nonces by address
    mapping(address => uint256) public nonces;

    /**
     * @notice Check request and revert when not valid. A valid request must:
     * - Include the expected value
     * - Not be expired
     * - Include the expected nonce
     * - Target a contract that accepts this forwarder
     * - Be signed by the original sender (`from` field)
     */
    // @audit-ok
    function _checkRequest(Request calldata request, bytes calldata signature) private view {
        // @audit-info Reverts if msg.value sent is different than the request value provided
        if (request.value != msg.value) revert InvalidValue();
        // @audit-info Reverts if request deadline exceeded
        if (block.timestamp > request.deadline) revert OldRequest();
        // @audit-info Reverts if request nonce does not match with internal nonce stored in 'from' account address
        if (nonces[request.from] != request.nonce) revert InvalidNonce();

        // @audit-info Reverts if target does not have this trusted forwarder configured
        if (IHasTrustedForwarder(request.target).trustedForwarder() != address(this)) revert InvalidTarget();

        // @audit-info Recovers the signer of the request (reverts if signer is address 0)
        address signer = ECDSA.recover(_hashTypedData(getDataHash(request)), signature);
        // @audit-info Reverts if recovered signer does not match with request from param
        if (signer != request.from) revert InvalidSigner();
    }

    // @audit-info Function to execute meta transaction
    // @audit-ok LGTM
    function execute(Request calldata request, bytes calldata signature) public payable returns (bool success) {
        // @audit-info Check request integrity and signature, reverts if invalid request
        _checkRequest(request, signature);

        // @audit-info Increments the nonce of the `request.from` account
        nonces[request.from]++;

        uint256 gasLeft;
        uint256 value = request.value; // in wei
        address target = request.target;
        bytes memory payload = abi.encodePacked(request.data, request.from);
        uint256 forwardGas = request.gas;
        assembly {
            // @audit-info Performs a call to the corresponding target, with the corresponding value and payload, forwarding the specified amount of gas
            success := call(forwardGas, target, value, add(payload, 0x20), mload(payload), 0, 0) // don't copy returndata
            // @audit-info Gets the gas left after the call was executed
            gasLeft := gas()
        }

        // @audit-info Ensures the contract was left with 1/63 of the request gas, reverts otherwise
        if (gasLeft < request.gas / 63) {
            assembly {
                invalid()
            }
        }
    }

    // @audit-info Getter function for domain name and version
    // @audit-ok LGTM
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "BasicForwarder";
        version = "1";
    }

    // @audit-info Function that returns the hashed data of a request
    // @audit-ok LGTM
    function getDataHash(Request memory request) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _REQUEST_TYPEHASH,
                request.from,
                request.target,
                request.value,
                request.gas,
                request.nonce,
                keccak256(request.data),
                request.deadline
            )
        );
    }

    // @audit-ok LGTM
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    // @audit-ok LGTM
    function getRequestTypehash() external pure returns (bytes32) {
        return _REQUEST_TYPEHASH;
    }
}
