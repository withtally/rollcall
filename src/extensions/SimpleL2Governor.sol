// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";
import {ERC20Votes} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

import {L2Governor} from "../standards/L2Governor.sol";
import {L2GovernorSettings} from "../standards/L2GovernorSettings.sol";
import {L2GovernorCountingSimple} from "../standards/L2GovernorCountingSimple.sol";
import {L2GovernorVotes} from "../standards/L2GovernorVotes.sol";
import {L2GovernorVotesQuorumFraction} from "../standards/L2GovernorVotesQuorumFraction.sol";

contract SimpleL2Governor is
    L2Governor,
    L2GovernorSettings,
    L2GovernorCountingSimple,
    L2GovernorVotes,
    L2GovernorVotesQuorumFraction
{
    constructor(
        ERC20Votes _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumNumeratorValue
    )
        L2Governor("RollCallGovernor")
        L2GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        L2GovernorVotes(_token)
        L2GovernorVotesQuorumFraction(_quorumNumeratorValue)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, L2GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, L2GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, L2GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, L2GovernorVotes)
        returns (uint256)
    {
        return super.getVotes(account, blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(L2Governor, L2GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
