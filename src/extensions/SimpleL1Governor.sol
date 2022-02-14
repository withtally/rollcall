// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {L1Governor} from "../L1Governor.sol";

contract SimpleL1Governor is L1Governor {
    struct Count {
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
    }
    mapping(bytes32 => Count) private _count;

    constructor(
        string memory name_,
        address[] memory sources_,
        bytes32[] memory slots_,
        address bridge_
    ) L1Governor(name_, sources_, slots_, bridge_) {}

    function quorum(uint256 blockNumber)
        public
        view
        override
        returns (uint256)
    {
        return 1;
    }

    function votingPeriod() public view override returns (uint256) {
        return 1;
    }

    /**
     * @dev Amount of votes already cast passes the threshold limit.
     */
    function _quorumReached(bytes32) internal view override returns (bool) {
        return true;
    }

    /**
     * @dev Is the proposal successful or not.
     */
    function _voteSucceeded(bytes32 id) internal view override returns (bool) {
        return _count[id].votesFor > _count[id].votesAgainst;
    }

    function _countVote(bytes32 id, uint256[10] memory votes)
        internal
        override
    {
        _count[id].votesAgainst += votes[0];
        _count[id].votesFor += votes[1];
        _count[id].votesAbstain += votes[2];
    }
}
