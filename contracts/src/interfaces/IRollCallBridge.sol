// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IRollCallBridge.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the {RollCallBridge} core.
 */
abstract contract IRollCallBridge {
    function propose(uint256 id) external virtual;
}
