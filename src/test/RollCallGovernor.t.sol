// SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {RollCallBridge} from "../RollCallBridge.sol";
import {RollCallGovernor} from "../RollCallGovernor.sol";
import {RollCallGovernorBasic} from "../extensions/RollCallGovernorBasic.sol";

contract GovernanceERC20 is ERC20 {
    constructor() ERC20("Rollcall", "ROLLCALL") public {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallGovernorTest is DSTest {
    GovernanceERC20 internal token;
    RollCallBridge internal bridge;
    RollCallGovernor internal governor;

    function setUp() public {
        governor = new RollCallGovernorBasic(
            "rollcall",
            address(token),
            bytes32('1'),
            address(bridge)
        );
    }

    function testCanPropose() public {
        assertTrue(true);
    }
}

