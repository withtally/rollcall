// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Context} from "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/draft-EIP712.sol";
import {ERC165} from "../lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";
import {IBridge} from "./interfaces/IBridge.sol";
import {IL1Governor} from "./interfaces/IL1Governor.sol";
import {IL2Voter} from "./interfaces/IL2Voter.sol";

import {iOVM_L1BlockNumber} from "./interfaces/iOVM_L1BlockNumber.sol";
import {Lib_PredeployAddresses} from "./lib/Lib_PredeployAddresses.sol";
import {RLPReader} from "./lib/RLPReader.sol";
import {StateProofVerifier as Verifier} from "./lib/StateProofVerifier.sol";

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
contract L2Voter is ERC165, EIP712, IL2Voter {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(bytes32 id,uint8 support)");

    iOVM_CrossDomainMessenger private immutable _cdm =
        iOVM_CrossDomainMessenger(0x4200000000000000000000000000000000000007);
    address private _bridge;

    mapping(address => mapping(bytes32 => Proposal)) private _proposals;
    mapping(address => mapping(bytes32 => uint256[10])) private _votes;
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        private _voted;
    mapping(address => mapping(bytes32 => address[])) private _sources;
    mapping(address => mapping(bytes32 => mapping(address => bytes32)))
        private _slots;
    mapping(address => mapping(bytes32 => mapping(address => Verifier.Account)))
        private _accounts;

    /**
     * @dev Sets the value for {name} and {version}
     */
    constructor(address bridge_) EIP712("rollcallvoter", version()) {
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
            interfaceId == type(IL2Voter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IL2Voter-name}.
     */
    function name() public view virtual override returns (string memory) {
        return "rollcallvoter";
    }

    /**
     * @dev See {IL2Voter-version}.
     */
    function version() public view virtual override returns (string memory) {
        return "1";
    }

    /**
     * @dev See {IL2Voter-state}.
     */
    function state(address governor, bytes32 id)
        public
        view
        virtual
        override
        returns (ProposalState)
    {
        Proposal storage proposal = _proposals[governor][id];

        require(proposal.start != 0, "rollcall: proposal vote doesnt exist");

        if (proposal.queue) {
            return ProposalState.Queued;
        }

        if (proposal.start > blocknumber()) {
            return ProposalState.Pending;
        }

        if (proposal.start <= blocknumber() && proposal.end > blocknumber()) {
            return ProposalState.Active;
        }

        return ProposalState.Ended;
    }

    function votes(address governor, bytes32 id)
        public
        view
        virtual
        override
        returns (uint256[10] memory)
    {
        return _votes[governor][id];
    }

    function proposal(address governor, bytes32 id)
        public
        view
        virtual
        override
        returns (Proposal memory)
    {
        return _proposals[governor][id];
    }

    function activate(
        address governor,
        bytes32 id,
        bytes memory blockHeaderRLP,
        bytes memory proofRlp
    ) external {
        Verifier.BlockHeader memory blockHeader = Verifier.parseBlockHeader(
            blockHeaderRLP
        );

        require(
            blockHeader.hash == _proposals[governor][id].snapshot,
            "voter: doesnt match snapshot"
        );

        _proposals[governor][id].stateroot = blockHeader.stateRootHash;

        RLPReader.RLPItem[] memory proofs = proofRlp.toRlpItem().toList();
        for (uint256 i = 0; i < _sources[governor][id].length; i++) {
            address source = _sources[governor][id][i];
            Verifier.Account memory account = Verifier.extractAccountFromProof(
                keccak256(abi.encodePacked(source)),
                blockHeader.stateRootHash,
                proofs[i].toList()
            );
            require(account.exists, "rollcall: account doesnt exist");
            _accounts[governor][id][source] = account;
        }
    }

    function propose(
        address governor,
        bytes32 id,
        address[] memory sources,
        bytes32[] memory slots,
        bytes32 snapshot,
        uint64 start,
        uint64 end
    ) external override onlyBridge {
        Proposal storage p = _proposals[governor][id];
        p.snapshot = snapshot;
        p.start = start;
        p.end = end;

        for (uint256 i = 0; i < slots.length; i++) {
            _sources[governor][id].push(sources[i]);
            _slots[governor][id][sources[i]] = slots[i];
        }
    }

    function queue(
        address governor,
        bytes32 id,
        uint32 gaslimit
    ) external override {
        require(state(governor, id) == ProposalState.Ended, "voter: not ready");

        _proposals[governor][id].queue = true;

        bytes memory message = abi.encodeWithSelector(
            IBridge.queue.selector,
            governor,
            id,
            _votes[governor][id]
        );

        _cdm.sendMessage(_bridge, message, gaslimit);
    }

    /**
     * @notice module:voting
     * @dev Returns weither `account` has cast a vote on `id`.
     */
    function hasVoted(
        address governor,
        bytes32 id,
        address account
    ) public view override returns (bool) {
        return _voted[governor][id][account];
    }

    /**
     * @dev See {IL2Voter-castVote}.
     */
    function castVote(
        bytes32 id,
        address source,
        address governor,
        bytes memory proofRlp,
        uint8 support
    ) public virtual override returns (uint256) {
        return
            _castVote(id, source, governor, msg.sender, proofRlp, support, "");
    }

    /**
     * @dev See {IL2Voter-castVoteWithReason}.
     */
    function castVoteWithReason(
        bytes32 id,
        address source,
        address governor,
        bytes memory proofRlp,
        uint8 support,
        string calldata reason
    ) public virtual override returns (uint256) {
        return
            _castVote(
                id,
                source,
                governor,
                msg.sender,
                proofRlp,
                support,
                reason
            );
    }

    /**
     * @dev See {IL2Voter-castVoteBySig}.
     */
    function castVoteBySig(
        bytes32 id,
        address source,
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
        return _castVote(id, source, governor, voter, proofRlp, support, "");
    }

    /**
     * @dev Internal vote casting mechanism: Check that the vote is pending and that it has not been cast yet.
     *
     * Emits a {IL2Voter-VoteCast} event.
     */
    function _castVote(
        bytes32 id,
        address source,
        address governor,
        address voter,
        bytes memory proofRlp,
        uint8 support,
        string memory reason
    ) internal virtual returns (uint256) {
        Verifier.Account memory a = _accounts[governor][id][source];
        require(
            state(governor, id) == ProposalState.Active,
            "rollcall: vote not currently active"
        );
        require(!_voted[governor][id][voter], "rollcall: already voted");
        require(a.exists, "rollcall: account doesnt exist");

        RLPReader.RLPItem[] memory proof = proofRlp.toRlpItem().toList();

        Verifier.SlotValue memory balance = Verifier.extractSlotValueFromProof(
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encodePacked(
                            bytes32(uint256(uint160(voter))),
                            _slots[governor][id][source]
                        )
                    )
                )
            ),
            a.storageRoot,
            proof
        );

        require(balance.exists, "voter: balance doesnt exist");

        _voted[governor][id][voter] = true;
        _votes[governor][id][support] += balance.value;

        emit VoteCast(voter, id, support, balance.value, reason);

        return balance.value;
    }

    /**
     * @dev Throws if called by any account other than the L1 bridge contract.
     */
    modifier onlyBridge() {
        require(
            msg.sender == address(_cdm) &&
                _cdm.xDomainMessageSender() == _bridge
        );
        _;
    }

    /**
     * @dev Returns the most recent layer 1 block number. This lags by 50 blocks (~15mins).
     */
    function blocknumber() private view returns (uint256) {
        return
            iOVM_L1BlockNumber(
                Lib_PredeployAddresses.L1_BLOCK_NUMBER // located at 0x4200000000000000000000000000000000000013
            ).getL1BlockNumber();
    }
}
