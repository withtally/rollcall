// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {OptimismVm, OptimismTest} from "forge-optimism/Optimism.sol";

import {Vm} from "./lib/Vm.sol";
import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallL1Governor} from "../interfaces/IRollCallL1Governor.sol";
import {SimpleRollCallL1Governor} from "../extensions/SimpleRollCallL1Governor.sol";

contract GovernanceERC20 is ERC20 {
    constructor() ERC20("Rollcall", "ROLLCALL") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallL1GovernorSetup is OptimismTest, DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    OptimismVm internal ovm = new OptimismVm();

    GovernanceERC20 internal token;
    RollCallBridge internal bridge;
    SimpleRollCallL1Governor internal governor;

    address[] internal sources = new address[](1);
    bytes32[] internal slots = new bytes32[](1);

    function setUp() public virtual override {
        token = new GovernanceERC20();

        bridge = new RollCallBridge(l1cdm);

        sources[0] = address(token);
        slots[0] = bytes32("1");

        governor = new SimpleRollCallL1Governor(
            "rollcall",
            sources,
            slots,
            address(bridge)
        );
    }
}

contract RollCallL1Governor_Constructor is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function testCannotConstructWithSourcesSlotsLengthMismatch() public {
        address[] memory sources = new address[](1);
        sources[0] = address(0);
        bytes32[] memory slots = new bytes32[](0);

        vm.expectRevert("governor: sources slots length mismatch");
        new SimpleRollCallL1Governor("rollcall", sources, slots, address(0));
    }
}

contract RollCallL1Governor_Metadata is RollCallL1GovernorSetup {
    function testExpectInitialMetadata() public {
        for (uint256 i = 0; i < slots.length; i++) {
            assertEq(governor.slots()[i], slots[i], "slots mismatch");
            assertEq(governor.sources()[i], sources[i], "sources mismatch");
        }

        assertEq(governor.version(), "1");
        assertEq(governor.name(), "rollcall");
        assertEq(governor.quorum(0), 1);
        assertEq(governor.votingPeriod(), 1);
    }
}
