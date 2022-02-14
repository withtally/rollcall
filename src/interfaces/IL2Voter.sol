// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IL2Voter.sol)

pragma solidity ^0.8.9;

import {IERC165} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";

import {IL1Governor} from "./IL1Governor.sol";

/**
 * @dev Interface of the {L2Voter} core.
 *
 * _Available since v4.3._
 */
abstract contract IL2Voter is IERC165 {
    enum ProposalState {
        Pending,
        Active,
        Ended,
        Queued
    }

    struct Proposal {
        bytes32 snapshot;
        bytes32 stateroot;
        uint64 start;
        uint64 end;
        bool queue;
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
     * @notice module:voter
     * @dev Name of the governor instance (used in building the ERC712 domain separator).
     */
    function name() public view virtual returns (string memory);

    /**
     * @notice module:voter
     * @dev Version of the governor instance (used in building the ERC712 domain separator). Default: "1"
     */
    function version() public view virtual returns (string memory);

    function propose(
        address governor,
        bytes32 id,
        address[] memory sources,
        bytes32[] memory slots,
        bytes32 snapshot,
        uint64 start,
        uint64 end
    ) external virtual;

    /**
     * @notice module:voter
     * @dev Queue an ended proposal for bridging to mainnet.
     */
    function queue(
        address governor,
        bytes32 id,
        uint32 gaslimit
    ) external virtual;

    /**
     * @notice module:voter
     * @dev Current state of a proposal vote
     */
    function state(address governor, bytes32 id)
        public
        view
        virtual
        returns (ProposalState);

    /**
     * @notice module:voter
     * @dev Current votes for a proposal
     */
    function votes(address governor, bytes32 id)
        public
        view
        virtual
        returns (uint256[10] memory);

    /**
     * @notice module:voter
     * @dev Current votes for a proposal
     */
    function proposal(address governor, bytes32 id)
        public
        view
        virtual
        returns (Proposal memory);

    /**
     * @notice module:voter
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
