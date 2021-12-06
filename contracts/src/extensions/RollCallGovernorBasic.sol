// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../extensions/RollCallGovernorCountingSimple.sol";

contract RollCallGovernorBasic is RollCallGovernorCountingSimple {
    constructor(
        string memory name_,
        address token_,
        uint256 slot_,
        address bridge_
    ) RollCallGovernor(name_, token_, slot_, bridge_) {}

    /**
     * @notice module:user-config
     * @dev Minimum number of cast voted required for a proposal to be successful.
     *
     * Note: The `blockNumber` parameter corresponds to the snaphot used for counting vote. This allows to scale the
     * quroum depending on values such as the totalSupply of a token at this block (see {ERC20Votes}).
     */
    function quorum(uint256 blockNumber)
        public
        view
        override
        returns (uint256)
    {
        return 0;
    }

    /**
     * @notice module:user-config
     * @dev Delay, in number of blocks, between the vote start and vote ends.
     */
    function votingPeriod() public view override returns (uint256) {
        return 0;
    }
}