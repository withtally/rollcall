// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/Governor.sol)

pragma solidity ^0.8.10;

import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

import {StateRoot} from "./lib/StateRoot.sol";
import {IRollCallGovernor} from "./interfaces/IRollCallGovernor.sol";
import {IRollCallBridge} from "./interfaces/IRollCallBridge.sol";

interface Token {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @dev Core of the governance system, designed to be extended though various modules.
 *
 * This contract is abstract and requires several function to be implemented in various modules:
 *
 * - A counting module must implement {quorum}, {_quorumReached}, {_voteSucceeded} and {_countVote}
 * - Additionanly, the {votingPeriod} must also be implemented
 *
 */
abstract contract RollCallGovernor is Context, ERC165, EIP712, IRollCallGovernor {
    using SafeCast for uint256;

    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    string private _name;
    address public override token;
    uint256 public override slot;
    IRollCallBridge private _bridge;

    mapping(uint256 => Proposal) private _proposals;

    /**
     * @dev Restrict access to governor executing address. Some module might override the _executor function to make
     * sure this modifier is consistant with the execution model.
     */
    modifier onlyGovernance() {
        require(_msgSender() == _executor(), "Governor: onlyGovernance");
        _;
    }

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(
        string memory name_,
        address token_,
        uint256 slot_,
        address bridge_
    ) EIP712(name_, version()) {
        _name = name_;
        token = token_;
        slot = slot_;
        _bridge = IRollCallBridge(bridge_);
    }

    /**
     * @dev Function to receive ETH that will be handled by the governor (disabled if executor is a third party contract)
     */
    receive() external payable virtual {
        require(_executor() == address(this));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IRollCallGovernor).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IRollCallGovernor-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IRollCallGovernor-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IRollCallGovernor-proposal}.
     */
    function proposal(uint256 id) public view override returns (Proposal memory) {
        return _proposals[id];
    }

    /**
     * @dev See {IRollCallGovernor-hashProposal}.
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
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual override returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }

    /**
     * @dev See {IRollCallGovernor-state}.
     */
    function state(uint256 proposalId) public view virtual override returns (ProposalState) {
        Proposal storage proposal_ = _proposals[proposalId];

        if (proposal_.executed) {
            return ProposalState.Executed;
        }

        if (proposal_.canceled) {
            return ProposalState.Canceled;
        }

        uint256 start = proposal_.start;

        if (start == 0) {
            revert("Governor: unknown proposal id");
        }

        if (start >= block.number) {
            return ProposalState.Pending;
        }

        uint256 deadline = proposalDeadline(proposalId);

        if (deadline >= block.number) {
            return ProposalState.Active;
        }

        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    /**
     * @dev See {IRollCallGovernor-proposalSnapshot}.
     */
    function proposalSnapshot(uint256 proposalId) public view virtual override returns (bytes32) {
        return _proposals[proposalId].root;
    }

    /**
     * @dev See {IRollCallGovernor-proposalDeadline}.
     */
    function proposalDeadline(uint256 proposalId) public view virtual override returns (uint256) {
        return _proposals[proposalId].end;
    }

    /**
     * @dev Part of the Governor Bravo's interface: _"The number of votes required in order for a voter to become a proposer"_.
     */
    function proposalThreshold() public view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Amount of votes already cast passes the threshold limit.
     */
    function _quorumReached(uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev Is the proposal successful or not.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual returns (bool);

    /**
     * @dev Register a vote with a given support and voting weight.
     *
     * Note: Support is generic and can represent various things depending on the voting system used.
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal virtual;

    /**
     * @dev See {IRollCallGovernor-propose}.
     */
    function propose(
        uint256 snapshot,
        bytes memory blockHeaderRLP,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        require(
            Token(token).balanceOf(msg.sender) >= proposalThreshold(),
            "Governor: proposer votes below proposal threshold"
        );

        uint256 proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        require(targets.length == values.length, "Governor: invalid proposal length");
        require(targets.length == calldatas.length, "Governor: invalid proposal length");
        require(targets.length > 0, "Governor: empty proposal");

        Proposal storage proposal_ = _proposals[proposalId];
        require(proposal_.start == 0, "Governor: proposal already exists");

        uint64 start = block.number.toUint64();
        uint64 deadline = start + votingPeriod().toUint64();

        proposal_.root = StateRoot.get(blockHeaderRLP, blockhash(snapshot));
        proposal_.start = start;
        proposal_.end = deadline;

        _bridge.propose(proposalId);

        emit ProposalCreated(
            proposalId,
            _msgSender(),
            targets,
            values,
            new string[](targets.length),
            calldatas,
            start,
            deadline,
            description
        );

        return proposalId;
    }

    function finalize(address governor, uint256 id) external override {}

    /**
     * @dev See {IRollCallGovernor-execute}.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        ProposalState status = state(proposalId);
        require(
            status == ProposalState.Succeeded || status == ProposalState.Queued,
            "Governor: proposal not successful"
        );
        _proposals[proposalId].executed = true;

        emit ProposalExecuted(proposalId);

        _execute(proposalId, targets, values, calldatas, descriptionHash);

        return proposalId;
    }

    /**
     * @dev Internal execution mechanism. Can be overriden to implement different execution mechanism
     */
    function _execute(
        uint256, /* proposalId */
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal virtual {
        string memory errorMessage = "Governor: call reverted without message";
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            Address.verifyCallResult(success, returndata, errorMessage);
        }
    }

    /**
     * @dev Internal cancel mechanism: locks up the proposal timer, preventing it from being re-submitted. Marks it as
     * canceled to allow distinguishing it from executed proposals.
     *
     * Emits a {IRollCallGovernor-ProposalCanceled} event.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        ProposalState status = state(proposalId);

        require(
            status != ProposalState.Canceled && status != ProposalState.Expired && status != ProposalState.Executed,
            "Governor: proposal not active"
        );
        _proposals[proposalId].canceled = true;

        emit ProposalCanceled(proposalId);

        return proposalId;
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
