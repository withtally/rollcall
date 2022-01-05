// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IRollCallBridge.sol)

pragma solidity 0.6.12;

/**
 * @dev Interface of the {RollCallBridge} core.
 */
abstract contract IRollCallBridge {
    function propose(bytes32 id) external virtual;

    function queue(
        address governor,
        bytes32 id,
        uint256[10] calldata votes
    ) external virtual;
}
