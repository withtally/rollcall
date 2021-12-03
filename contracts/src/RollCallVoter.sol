// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";
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
abstract contract RollCallVoter is Context, ERC165, EIP712, IRollCallVoter {
    using SafeCast for uint256;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 id,uint8 support)");

    struct Proposal {
        address token;
        bytes32 root;
        uint256 slot;
        uint64 start;
        uint64 end;
        bool canceled;
    }

    string private _name;
    iOVM_CrossDomainMessenger private _cdm;
    address private _bridge;

    mapping(address => mapping(uint256 => Proposal)) private _proposals;

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(string memory name_, address initiator_)
        EIP712(name_, version())
    {
        _name = name_;
        _bridge = initiator_;
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

        require(proposal.start != 0, "RollCall: proposal vote doesnt exist");

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.start > block.number) {
            return ProposalState.Pending;
        }

        if (proposal.start <= block.number && proposal.end > block.number) {
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
        Proposal storage proposal_ = _proposals[governor][id];
        proposal_.token = token;
        proposal_.slot = slot;
        proposal_.root = root;
        proposal_.start = start;
        proposal_.end = end;
    }

    /**
     * @dev See {IRollCallVoter-castVote}.
     */
    function castVote(
        uint256 id,
        address governor,
        uint256 balance,
        bytes32[] memory proof,
        uint8 support
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(id, governor, voter, balance, proof, support, "");
    }

    /**
     * @dev See {IRollCallVoter-castVoteWithReason}.
     */
    function castVoteWithReason(
        uint256 id,
        address governor,
        uint256 balance,
        bytes32[] memory proof,
        uint8 support,
        string calldata reason
    ) public virtual override returns (uint256) {
        address voter = _msgSender();
        return _castVote(id, governor, voter, balance, proof, support, reason);
    }

    /**
     * @dev See {IRollCallVoter-castVoteBySig}.
     */
    function castVoteBySig(
        uint256 id,
        address governor,
        uint256 balance,
        bytes32[] memory proof,
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
        return _castVote(id, governor, voter, balance, proof, support, "");
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending, that it has not been cast yet, retrieve
     * voting weight using {IRollCallVoter-getVotes} and call the {_countVote} internal function.
     *
     * Emits a {IRollCallVoter-VoteCast} event.
     */
    function _castVote(
        uint256 id,
        address governor,
        address account,
        uint256 balance,
        bytes32[] memory proof,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        Proposal storage proposal = _proposals[governor][id];
        require(
            state(governor, id) == ProposalState.Active,
            "RollCall: vote not currently active"
        );

        require(
            MerkleProof.verify(proof, proposal.root, bytes32(balance)),
            "RollCall: invalid balance"
        );

        emit VoteCast(account, id, support, balance, reason);

        return balance;
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
