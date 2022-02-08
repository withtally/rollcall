// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "openzeppelin-contracts/governance/Governor.sol";
import "openzeppelin-contracts/governance/extensions/GovernorSettings.sol";
import "openzeppelin-contracts/governance/extensions/GovernorCountingSimple.sol";
import "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";
import "openzeppelin-contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "openzeppelin-contracts/governance/extensions/GovernorTimelockControl.sol";
import "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

contract RollCallGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    constructor(
        ERC20Votes _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumNumeratorValue
    )
        Governor("RollCallGovernor")
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumNumeratorValue)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotes)
        returns (uint256)
    {
        return super.getVotes(account, blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
