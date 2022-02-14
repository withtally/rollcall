// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IBridge.sol)

pragma solidity ^0.8.9;

/**
 * @dev Interface of the {Bridge} core.
 */
abstract contract IBridge {
    function propose(bytes32 id) external virtual;

    function queue(
        address governor,
        bytes32 id,
        uint256[10] calldata votes
    ) external virtual;
}
