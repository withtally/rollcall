// SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallGovernor} from "../interfaces/IRollCallGovernor.sol";
import {RollCallGovernor} from "../RollCallGovernor.sol";

contract GovernanceERC20 is ERC20 {
    constructor() public ERC20("Rollcall", "ROLLCALL") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallGovernorTest is DSTest {
    GovernanceERC20 internal token;
    RollCallBridge internal bridge;
    RollCallGovernor internal governor;

    function setUp() public {
        address[] memory sources = new address[](1);
        sources[0] = address(token);
        bytes32[] memory slots = new bytes32[](1);
        slots[0] = bytes32("1");

        governor = new RollCallGovernor(
            "rollcall",
            sources,
            slots,
            address(bridge)
        );
    }

    function testCanPropose() public {
        assertTrue(true);
    }
}
