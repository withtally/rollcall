// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IRollCallBridge} from "./interfaces/IRollCallBridge.sol";
import {IRollCallGovernor} from "./interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "./interfaces/IRollCallVoter.sol";
import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";

contract RollCallBridge is IRollCallBridge, Ownable {
    iOVM_CrossDomainMessenger private immutable _cdm;
    address public voter;

    constructor(iOVM_CrossDomainMessenger cdm_) public {
        _cdm = cdm_;
    }

    function setVoter(address voter_) external onlyOwner {
        voter = voter_;
    }

    function propose(uint256 id) external override {
        IRollCallGovernor governor = IRollCallGovernor(msg.sender);
        IRollCallGovernor.Proposal memory proposal = governor.proposal(id);

        bytes memory message = abi.encodeWithSelector(
            IRollCallVoter.propose.selector,
            msg.sender,
            id,
            governor.sources(),
            governor.slots(),
            proposal.root,
            proposal.start,
            proposal.end
        );

        _cdm.sendMessage(voter, message, 1900000); // 1900000 gas is given for free
    }

    function finalize(
        address governor,
        uint256 id,
        uint256[3] calldata votes
    ) external override onlyVoter {
        IRollCallGovernor(governor).finalize(id, votes);
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
