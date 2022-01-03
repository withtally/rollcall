// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IRollCallVoter.sol)

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/introspection/ERC165.sol";

import {IRollCallGovernor} from "./IRollCallGovernor.sol";

/**
 * @dev Interface of the {RollCallVoter} core.
 *
 * _Available since v4.3._
 */
abstract contract IRollCallVoter is IERC165 {
    enum ProposalState {
        Pending,
        Active,
        Ended,
        Finalized
    }

    /**
     * @dev Emitted when a vote is cast.
     *
     * Note: `support` values should be seen as buckets. There interpretation depends on the voting module used.
     */
    event VoteCast(
        address indexed voter,
        bytes32 id,
        uint8 support,
        uint256 weight,
        string reason
    );

    /**
     * @notice module:core
     * @dev Name of the governor instance (used in building the ERC712 domain separator).
     */
    function name() public view virtual returns (string memory);

    /**
     * @notice module:core
     * @dev Version of the governor instance (used in building the ERC712 domain separator). Default: "1"
     */
    function version() public view virtual returns (string memory);

    function propose(
        address governor,
        bytes32 id,
        address[] memory sources,
        bytes32[] memory slots,
        bytes32 root,
        uint64 start,
        uint64 end
    ) external virtual;

    function finalize(
        address governor,
        bytes32 id,
        uint32 gaslimit
    ) external virtual;

    /**
     * @notice module:core
     * @dev Current state of a proposal vote
     */
    function state(address governor, bytes32 id)
        public
        view
        virtual
        returns (ProposalState);

    /**
     * @notice module:voting
     * @dev Returns weither `account` has cast a vote on `id` for a partciular governor.
     */
    function hasVoted(
        address governor,
        bytes32 id,
        address account
    ) public view virtual returns (bool);

    /**
     * @dev Cast a vote
     *
     * Emits a {VoteCast} event.
     */
    function castVote(
        bytes32 id,
        address token,
        address governor,
        bytes memory proofRlp,
        uint8 support
    ) public virtual returns (uint256);

    /**
     * @dev Cast a with a reason
     *
     * Emits a {VoteCast} event.
     */
    function castVoteWithReason(
        bytes32 id,
        address token,
        address governor,
        bytes memory proofRlp,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256);

    /**
     * @dev Cast a vote using the user cryptographic signature.
     *
     * Emits a {VoteCast} event.
     */
    function castVoteBySig(
        bytes32 id,
        address token,
        address governor,
        bytes memory proofRlp,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual returns (uint256);
}
