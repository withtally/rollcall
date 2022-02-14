// SPDX-License-Identifier: MIT
// Forked from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/Governor.sol
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {ERC165} from "../lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import {IL1Governor} from "./interfaces/IL1Governor.sol";
import {IBridge} from "./interfaces/IBridge.sol";

/**
 * @dev Core of the governance system, designed to be extended though various modules.
 * - A counting module must implement {quorum}, {_quorumReached}, {_voteSucceeded} and {_countVote}
 */
abstract contract L1Governor is ERC165, EIP712, IL1Governor {
    string private _name;
    IBridge private _bridge;

    uint256 private _quorum;
    address[] private _sources;
    bytes32[] private _slots;
    mapping(bytes32 => Proposal) private _proposals;

    /**
     * @dev Restrict access to bridge implementation address.
     */
    modifier onlyBridge() {
        require(msg.sender == address(_bridge), "governor: not bridge");
        _;
    }

    /**
     * @dev Restrict access to governor executing address. Some module might override the _executor function to make
     * sure this modifier is consistant with the execution model.
     */
    modifier onlyGovernance() {
        require(msg.sender == _executor(), "governor: not governance");
        _;
    }

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(
        string memory name_,
        address[] memory sources_,
        bytes32[] memory slots_,
        address bridge_
    ) EIP712(name_, version()) {
        require(
            sources_.length == slots_.length,
            "governor: sources slots length mismatch"
        );
        _name = name_;
        _bridge = IBridge(bridge_);

        for (uint256 i = 0; i < sources_.length; i++) {
            _sources.push(sources_[i]);
            _slots.push(slots_[i]);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165)
        returns (bool)
    {
        return
            interfaceId == type(IL1Governor).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IL1Governor-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IL1Governor-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IL1Governor-sources}.
     */
    function sources() external view override returns (address[] memory) {
        return _sources;
    }

    /**
     * @dev See {IL1Governor-slots}.
     */
    function slots() external view override returns (bytes32[] memory) {
        return _slots;
    }

    /**
     * @notice module:user-config
     * @dev Minimum number of cast voted required for a proposal to be successful.
     *
     * Note: The `blockNumber` parameter corresponds to the snaphot used for counting vote. This allows to scale the
     * quroum depending on values such as the totalSupply of a token at this block (see {ERC20Votes}).
     */
    function quorum(uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256);

    /**
     * @notice module:user-config
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     */
    function votingPeriod() public view virtual override returns (uint256);

    /**
     * @dev See {IL1Governor-proposal}.
     */
    function proposal(bytes32 id)
        public
        view
        override
        returns (Proposal memory)
    {
        return _proposals[id];
    }

    /**
     * @dev See {IL1Governor-hash}.
     *
     * The proposal id is produced by hashing the RLC encoded `targets` array, the `values` array, the `calldatas` array
     * and the descriptionHash (bytes32 which itself is the keccak256 hash of the description string). This proposal id
     * can be produced from the proposal data which is part of the {ProposalCreated} event. It can even be computed in
     * advance, before the proposal is submitted.
     *
     * Note that the chainId and the governor address are not part of the proposal id computation. Consequently, the
     * same proposal (with same operation and same description) will have the same id if submitted on multiple governors
     * accross multiple networks. This also means that in order to execute the same operation twice (on the same
     * governor) the proposer will have to change the description in order to avoid proposal id conflicts.
     */
    function hash(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual override returns (bytes32) {
        return
            keccak256(abi.encode(targets, values, calldatas, descriptionHash));
    }

    /**
     * @dev See {IL1Governor-state}.
     */
    function state(bytes32 id)
        public
        view
        virtual
        override
        returns (ProposalState)
    {
        Proposal storage proposal_ = _proposals[id];

        if (proposal_.executed) {
            return ProposalState.Executed;
        }

        if (proposal_.canceled) {
            return ProposalState.Canceled;
        }

        uint256 start = proposal_.start;

        if (start == 0) {
            revert("governor: unknown proposal id");
        }

        if (start >= block.number) {
            return ProposalState.Pending;
        }

        uint256 deadline = proposalDeadline(id);

        if (deadline >= block.number) {
            return ProposalState.Active;
        }

        if (_quorumReached(id) && _voteSucceeded(id)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    /**
     * @dev See {IL1Governor-proposalSnapshot}.
     */
    function proposalSnapshot(bytes32 id)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return _proposals[id].snapshot;
    }

    /**
     * @dev See {IL1Governor-proposalDeadline}.
     */
    function proposalDeadline(bytes32 id)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _proposals[id].end;
    }

    /**
     * @dev Amount of votes already cast passes the threshold limit.
     */
    function _quorumReached(bytes32 id) internal view virtual returns (bool);

    /**
     * @dev Is the proposal successful or not.
     */
    function _voteSucceeded(bytes32 id) internal view virtual returns (bool);

    /**
     * @dev Count a proposals votes.
     */
    function _countVote(bytes32 id, uint256[10] memory votes) internal virtual;

    /**
     * @dev See {IL1Governor-propose}.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (bytes32) {
        bytes32 id = hash(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        require(
            targets.length == values.length,
            "governor: invalid proposal length"
        );
        require(
            targets.length == calldatas.length,
            "governor: invalid proposal length"
        );
        require(targets.length > 0, "governor: empty proposal");

        Proposal storage proposal_ = _proposals[id];
        require(proposal_.start == 0, "governor: proposal already exists");

        uint64 start = uint64(block.number);

        // TODO: Make sure safe cast
        uint64 deadline = start + uint64(votingPeriod());

        proposal_.snapshot = blockhash(block.number - 1);
        proposal_.start = start;
        proposal_.end = deadline;

        _bridge.propose(id);

        emit ProposalCreated(
            id,
            msg.sender,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            start,
            deadline,
            description
        );

        return id;
    }

    /**
     * @dev See {IL1Governor-queue}.
     */
    function queue(bytes32 id, uint256[10] memory votes)
        external
        override
        onlyBridge
    {
        _countVote(id, votes);
    }

    /**
     * @dev See {IL1Governor-execute}.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual override returns (bytes32) {
        bytes32 id = hash(targets, values, calldatas, descriptionHash);

        ProposalState status = state(id);
        require(
            status == ProposalState.Succeeded || status == ProposalState.Queued,
            "governor: proposal not successful"
        );
        _proposals[id].executed = true;

        emit ProposalExecuted(id);

        for (uint256 i = 0; i < targets.length; ++i) {
            Address.functionCallWithValue(targets[i], calldatas[i], values[i]);
        }

        return id;
    }

    /**
     * @dev Internal cancel mechanism: locks up the proposal timer, preventing it from being re-submitted. Marks it as
     * canceled to allow distinguishing it from executed proposals.
     *
     * Emits a {IL1Governor-ProposalCanceled} event.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (bytes32) {
        bytes32 id = hash(targets, values, calldatas, descriptionHash);
        ProposalState status = state(id);

        require(
            status != ProposalState.Canceled &&
                status != ProposalState.Expired &&
                status != ProposalState.Executed,
            "governor: proposal not active"
        );
        _proposals[id].canceled = true;

        emit ProposalCanceled(id);

        return id;
    }

    /**
     * @dev Relays a transaction or function call to an arbitrary target. In cases where the governance executor
     * is some contract other than the governor itself, like when using a timelock, this function can be invoked
     * in a governance proposal to recover tokens or Ether that was sent to the governor contract by mistake.
     * Note that if the executor is simply the governor itself, use of `relay` is redundant.
     */
    function relay(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyGovernance {
        Address.functionCallWithValue(target, data, value);
    }

    /**
     * @dev Address through which the governor executes action. Will be overloaded by module that execute actions
     * through another contract such as a timelock.
     */
    function _executor() internal view virtual returns (address) {
        return address(this);
    }
}
