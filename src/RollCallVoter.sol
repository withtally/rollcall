// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

import {StateProofVerifier as Verifier} from "curve-merkle-oracle/StateProofVerifier.sol";

import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";
import {IRollCallGovernor} from "./interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "./interfaces/IRollCallVoter.sol";

/**
 * @dev Core of the governance system, designed to be extended though various modules.
 *
 * This contract is abstract and requires several function to be implemented in various modules:
 *
 * - A counting module must implement {quorum}, {_quorumReached}, {_voteSucceeded} and {_countVote}
 * - A voting module must implement {getVotes}
 * - Additionanly, the {votingPeriod} must also be implemented
 *
 */
contract RollCallVoter is Context, ERC165, EIP712, IRollCallVoter {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 id,uint8 support)");

    struct Proposal {
        address token;
        bytes32 root;
        bytes32 slot;
        uint64 start;
        uint64 end;
    }

    string private _name;
    iOVM_CrossDomainMessenger private immutable _cdm;
    address private _bridge;

    mapping(address => mapping(uint256 => Proposal)) private _proposals;

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(
        string memory name_,
        address cdm_,
        address bridge_
    ) EIP712(name_, version()) {
        _name = name_;
        _cdm = iOVM_CrossDomainMessenger(cdm_);
        _bridge = bridge_;
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
            interfaceId == type(IRollCallVoter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IRollCallVoter-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IRollCallVoter-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IRollCallGovernor-state}.
     */
    function state(address governor, uint256 id)
        public
        view
        virtual
        override
        returns (ProposalState)
    {
        Proposal storage proposal = _proposals[governor][id];

        require(proposal.start != 0, "rollcall: proposal vote doesnt exist");

        if (proposal.start > block.timestamp) {
            return ProposalState.Pending;
        }

        if (
            proposal.start <= block.timestamp && proposal.end > block.timestamp
        ) {
            return ProposalState.Active;
        }

        return ProposalState.Ended;
    }

    function propose(
        address governor,
        address token,
        uint256 slot,
        uint256 id,
        bytes32 root,
        uint64 start,
        uint64 end
    ) external override onlyBridge {
        Proposal storage proposal = _proposals[governor][id];
        proposal.token = token;
        proposal.slot = slot;
        proposal.root = root;
        proposal.start = start;
        proposal.end = end;
    }

    function finalize(address governor, uint256 id) external {
        Proposal memory proposal = _proposals[governor][id];
        // TODO: Use L1 block number
        require(proposal.end < block.number, "voter: voting in progress");

        bytes memory message = abi.encodeWithSelector(
            IRollCallGovernor.finalize.selector,
            governor,
            id
            // slot,
            // id,
            // proposal.root,
            // proposal.start,
            // proposal.end
        );

        _cdm.sendMessage(_bridge, message, 1000000);
    }

    /**
     * @notice module:voting
     * @dev Returns weither `account` has cast a vote on `id`.
     */
    function hasVoted(uint256 id, address account)
        public
        view
        override
        returns (bool)
    {
        return false;
    }

    /**
     * @dev See {IRollCallVoter-castVote}.
     */
    function castVote(
        uint256 id,
        address governor,
        bytes memory proofRlp,
        uint8 support
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(id, governor, voter, proof, support, "");
    }

    /**
     * @dev See {IRollCallVoter-castVoteWithReason}.
     */
    function castVoteWithReason(
        uint256 id,
        address governor,
        bytes memory proofRlp,
        uint8 support,
        string calldata reason
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(id, governor, voter, proof, support, reason);
    }

    /**
     * @dev See {IRollCallVoter-castVoteBySig}.
     */
    function castVoteBySig(
        uint256 id,
        address governor,
        bytes memory proofRlp,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override returns (uint256) {
        address voter = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(abi.encode(BALLOT_TYPEHASH, id, support))
            ),
            v,
            r,
            s
        );
        return _castVote(id, governor, voter, proof, support, "");
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet,
     * and call the {_countVote} internal function.
     *
     * Emits a {IRollCallVoter-VoteCast} event.
     */
    function _castVote(
        uint256 id,
        address governor,
        address account,
        bytes memory proofRlp,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        Proposal storage proposal = _proposals[governor][id];
        require(
            state(governor, id) == ProposalState.Active,
            "rollcall: vote not currently active"
        );

        RLPReader.RLPItem[] memory proofs = proofRlp.toRlpItem().toList();

        Verifier.SlotValue memory balance = Verifier.extractSlotValueFromProof(
            proposal.slot,
            proposal.root,
            proofs
        );

        require(balance.exists, "voter: balance doesnt exist");

        emit VoteCast(account, id, support, balance.value, reason);

        return balance.value;
    }

    /**
     * @dev Throws if called by any account other than the l1 bridge.
     */
    modifier onlyBridge() {
        require(
            msg.sender == address(_cdm) &&
                _cdm.xDomainMessageSender() == _bridge
        );
        _;
    }
}
