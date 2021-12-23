// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IRollCallBridge.sol)

pragma solidity 0.6.12;

/**
 * @dev Interface of the {RollCallBridge} core.
 */
abstract contract IRollCallBridge {
    function propose(uint256 id) external virtual;

    function finalize(
        address governor,
        uint256 id,
        uint256[10] memory votes
    ) external virtual;
}
