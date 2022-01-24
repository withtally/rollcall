// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";

contract RollCallExecutor {
    iOVM_CrossDomainMessenger private immutable _cdm;
    address public immutable l2dao;
    address public immutable timelock;

    constructor(
        address cdm,
        address timelock_,
        address l2dao_
    ) public {
        _cdm = iOVM_CrossDomainMessenger(cdm);
        timelock = timelock_;
        l2dao = l2dao_;
    }

    /**
     * @dev Proxies an execution payload bridged from Layer 2. Verfies the
     * execution payload source is the configured Layer 2 Governance.
     *
     */
    function execute(bytes memory data) public payable onlyL2DAO {
        Address.functionCallWithValue(payable(timelock), data, msg.value);
    }

    /**
     * @dev Throws if called by any account other than the L2 dao contract.
     */
    modifier onlyL2DAO() {
        require(
            msg.sender == address(_cdm) && _cdm.xDomainMessageSender() == l2dao,
            "executor: not dao"
        );
        _;
    }
}
