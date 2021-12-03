// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IRollCallGovernor} from "./interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "./interfaces/IRollCallVoter.sol";
import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";

contract RollCallBridge {
    iOVM_CrossDomainMessenger private immutable _ovm;
    address private immutable _voter;

    constructor(iOVM_CrossDomainMessenger ovm_, address voter_) {
        _ovm = ovm_;
        _voter = voter_;
    }

    function propose(uint256 id) external {
        IRollCallGovernor governor = IRollCallGovernor(msg.sender);
        address token = governor.token();
        uint256 slot = governor.slot();

        IRollCallGovernor.Proposal memory proposal = governor.proposal(id);

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

        _ovm.sendMessage(address(_voter), message, 1900000); // 1900000 gas is given for free
    }
}
