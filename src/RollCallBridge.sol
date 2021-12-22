// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {IRollCallGovernor} from "./interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "./interfaces/IRollCallVoter.sol";
import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";

contract RollCallBridge is Ownable {
    iOVM_CrossDomainMessenger private immutable _cdm;
    address public voter;

    constructor(iOVM_CrossDomainMessenger cdm_) public {
        _cdm = cdm_;
    }

    function setVoter(address voter_) external onlyOwner {
        voter = voter_;
    }

    function propose(uint256 id) external {
        IRollCallGovernor governor = IRollCallGovernor(msg.sender);
        address token = governor.token();
        bytes32 slot = governor.slot();

        IRollCallGovernor.Proposal memory proposal = governor.proposal(id);

        require(
            proposal.end > block.timestamp,
            "bridge: proposal end before now"
        );

        bytes memory message = abi.encodeWithSelector(
            IRollCallVoter.propose.selector,
            msg.sender,
            token,
            slot,
            id,
            proposal.root,
            proposal.start,
            proposal.end
        );

        _cdm.sendMessage(voter, message, 1900000); // 1900000 gas is given for free
    }

    function tally() external onlyVoter {
        
    }

    /**
     * @dev Throws if called by any account other than the L2 voter contract.
     */
    modifier onlyVoter() {
        require(
            msg.sender == address(_cdm) && _cdm.xDomainMessageSender() == voter
        );
        _;
    }
}
