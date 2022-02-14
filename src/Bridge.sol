// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {iOVM_CrossDomainMessenger} from "forge-optimism/interfaces/iOVM_CrossDomainMessenger.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {IBridge} from "./interfaces/IBridge.sol";
import {IL1Governor} from "./interfaces/IL1Governor.sol";
import {IL2Voter} from "./interfaces/IL2Voter.sol";

contract Bridge is IBridge, Ownable {
    iOVM_CrossDomainMessenger private immutable _cdm;
    address public voter;

    constructor(iOVM_CrossDomainMessenger cdm_) {
        _cdm = cdm_;
    }

    function setVoter(address voter_) external onlyOwner {
        voter = voter_;
    }

    function propose(bytes32 id) external override {
        IL1Governor governor = IL1Governor(msg.sender);
        IL1Governor.Proposal memory proposal = governor.proposal(id);

        bytes memory message = abi.encodeWithSelector(
            IL2Voter.propose.selector,
            msg.sender,
            id,
            governor.sources(),
            governor.slots(),
            proposal.snapshot,
            proposal.start,
            proposal.end
        );

        _cdm.sendMessage(voter, message, 1900000); // 1900000 gas is given for free
    }

    function queue(
        address governor,
        bytes32 id,
        uint256[10] calldata votes
    ) external override onlyVoter {
        IL1Governor(governor).queue(id, votes);
    }

    /**
     * @dev Throws if called by any account other than the L2 voter contract.
     */
    modifier onlyVoter() {
        require(
            msg.sender == address(_cdm) && _cdm.xDomainMessageSender() == voter,
            "bridge: not voter"
        );
        _;
    }
}
