// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {iOVM_CrossDomainMessenger} from "forge-optimism/interfaces/iOVM_CrossDomainMessenger.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {IRollCallBridge} from "./interfaces/IRollCallBridge.sol";
import {IRollCallL1Governor} from "./interfaces/IRollCallL1Governor.sol";
import {IRollCallVoter} from "./interfaces/IRollCallVoter.sol";

contract RollCallBridge is IRollCallBridge, Ownable {
    iOVM_CrossDomainMessenger private immutable _cdm;
    address public voter;

    constructor(iOVM_CrossDomainMessenger cdm_) {
        _cdm = cdm_;
    }

    function setVoter(address voter_) external onlyOwner {
        voter = voter_;
    }

    function propose(bytes32 id) external override {
        IRollCallL1Governor governor = IRollCallL1Governor(msg.sender);
        IRollCallL1Governor.Proposal memory proposal = governor.proposal(id);

        bytes memory message = abi.encodeWithSelector(
            IRollCallVoter.propose.selector,
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
        IRollCallL1Governor(governor).queue(id, votes);
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
