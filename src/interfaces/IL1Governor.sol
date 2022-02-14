// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (governance/IGovernor.sol)

pragma solidity ^0.8.9;

import {IERC165} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";

/**
 * @dev Interface of the {Governor} core.
 *
 * _Available since v4.3._
 */
abstract contract IL1Governor is IERC165 {
    struct Proposal {
        bytes32 snapshot;
        uint64 start;
        uint64 end;
        bool executed;
        bool canceled;
    }

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * @dev Emitted when a proposal is created.
     */
    event ProposalCreated(
        bytes32 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /**
     * @dev Emitted when a proposal is canceled.
     */
    event ProposalCanceled(bytes32 id);

    /**
     * @dev Emitted when a proposal is executed.
     */
    event ProposalExecuted(bytes32 id);

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

    /**
     * @notice module:core
     * @dev A governance proposal.
     */
    function proposal(bytes32 id) public view virtual returns (Proposal memory);

    /**
     * @notice module:core
     * @dev Sources for voting balances. Corresponds 1:1 with `slots`.
     */
    function sources() external view virtual returns (address[] memory);

    /**
     * @notice module:core
     * @dev Storage Slots for voting balances. Corresponds 1:1 with `sources`.
     */
    function slots() external view virtual returns (bytes32[] memory);

    /**
     * @notice module:core
     * @dev Hashing function used to (re)build the proposal id from the proposal details..
     */
    function hash(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (bytes32);

    /**
     * @notice module:core
     * @dev Current state of a proposal, following Compound's convention
     */
    function state(bytes32 id) public view virtual returns (ProposalState);

    /**
     * @notice module:core
     * @dev Block number the storage root was commited, which is used to retrieve user's votes and quorum.
     */
    function proposalSnapshot(bytes32 id) public view virtual returns (bytes32);

    /**
     * @notice module:core
     * @dev Block number at which votes close. Votes close at the end of this block, so it is possible to cast a vote
     * during this block.
     */
    function proposalDeadline(bytes32 id) public view virtual returns (uint256);

    /**
     * @notice module:user-config
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     */
    function votingPeriod() public view virtual returns (uint256);

    /**
     * @notice module:user-config
     * @dev Minimum number of cast voted required for a proposal to be successful.
     *
     * Note: The `blockNumber` parameter corresponds to the snaphot used for counting vote. This allows to scale the
     * quroum depending on values such as the totalSupply of a token at this block (see {ERC20Votes}).
     */
    function quorum(uint256 blockNumber) public view virtual returns (uint256);

    /**
     * @dev Create a new proposal. Vote start after the proposal is created and ends
     * {IGovernor-votingPeriod} blocks after the voting starts.
     *
     * Emits a {ProposalCreated} event.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (bytes32 id);

    /**
     * @dev Queue a proposal for execution.
     */
    function queue(bytes32 id, uint256[10] calldata votes) external virtual;

    /**
     * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
     * deadline to be reached.
     *
     * Emits a {ProposalExecuted} event.
     *
     * Note: some module can modify the requirements for execution, for example by adding an additional timelock.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (bytes32 id);
}
