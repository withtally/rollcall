// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import {iOVM_CrossDomainMessenger} from "./interfaces/iOVM_CrossDomainMessenger.sol";

contract Executor {
    error UNDERLYING_CONTRACT_REVERTED();

    iOVM_CrossDomainMessenger private immutable _cdm;
    address public immutable l2dao;

    constructor(address cdm, address l2dao_) {
        _cdm = iOVM_CrossDomainMessenger(cdm);
        l2dao = l2dao_;
    }

    /**
     * @dev Proxies an execution payload bridged from Layer 2. Verfies the
     * execution payload source is the configured Layer 2 Governance.
     *
     */
    function execute(address target, bytes memory data) public onlyL2DAO {
        (bool success, ) = target.call(data);
        if (!success) {
            revert UNDERLYING_CONTRACT_REVERTED();
        }
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
