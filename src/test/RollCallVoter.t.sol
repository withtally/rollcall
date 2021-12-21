// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {iOVM_FakeCrossDomainMessenger} from "./iOVM_FakeCrossDomainMessenger.sol";
import {Vm} from "./lib/Vm.sol";

import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallGovernor} from "../interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "../interfaces/IRollCallVoter.sol";
import {RollCallVoter} from "../RollCallVoter.sol";

contract GovernanceERC20 is ERC20 {
    constructor() ERC20("Rollcall", "ROLLCALL") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallProposer {
    RollCallBridge internal bridge;

    mapping(uint256 => IRollCallGovernor.Proposal) internal proposals;

    constructor(address bridge_) {
        bridge = RollCallBridge(bridge_);
    }

    function propose(uint256 id, IRollCallGovernor.Proposal memory p) external {
        proposals[id] = p;
        bridge.propose(id);
    }

    function proposal(uint256 id)
        public
        view
        virtual
        returns (IRollCallGovernor.Proposal memory)
    {
        return proposals[id];
    }

    function token() external view virtual returns (address) {
        return 0x7aE1D57b58fA6411F32948314BadD83583eE0e8C;
    }

    function slot() external view virtual returns (uint256) {
        return 0;
    }
}

contract RollCallVoterSetup is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    GovernanceERC20 internal token;
    iOVM_FakeCrossDomainMessenger internal cdm;
    RollCallBridge internal bridge;
    RollCallVoter internal voter;
    RollCallProposer internal proposer;

    function setUp() public virtual {
        cdm = new iOVM_FakeCrossDomainMessenger();

        bridge = new RollCallBridge(cdm);

        voter = new RollCallVoter("rollcall", address(cdm), address(bridge));

        proposer = new RollCallProposer(address(bridge));

        bridge.setVoter(address(voter));
    }
}

contract RollCallVoterProposing is RollCallVoterSetup {
    function setUp() public override {
        super.setUp();
    }

    function testCanPropose() public {
        uint64 ts = uint64(block.timestamp);
        proposer.propose(
            1,
            IRollCallGovernor.Proposal({
                root: hex"aa4b6e9974527b5c8a26e9892701df673ad9fb7ac3d0f4641673bd67923f4730",
                start: ts,
                end: ts + 100,
                executed: false,
                canceled: false
            })
        );
    }

    function testCantProposeWhenAfterEnd() public {
        uint64 ts = uint64(block.timestamp);
        vm.warp(block.timestamp + 101);
        vm.expectRevert("bridge: proposal end before now");
        proposer.propose(
            1,
            IRollCallGovernor.Proposal({
                root: hex"aa4b6e9974527b5c8a26e9892701df673ad9fb7ac3d0f4641673bd67923f4730",
                start: ts,
                end: ts + 100,
                executed: false,
                canceled: false
            })
        );
    }
}

contract RollCallVoterVoting is RollCallVoterSetup {
    uint64 internal ts = uint64(block.timestamp);
    uint64 internal start = ts + 10;
    uint64 internal end = ts + 100;

    function setUp() public override {
        super.setUp();

        proposer.propose(
            1,
            IRollCallGovernor.Proposal({
                root: hex"aa4b6e9974527b5c8a26e9892701df673ad9fb7ac3d0f4641673bd67923f4730",
                start: start,
                end: end,
                executed: false,
                canceled: false
            })
        );
    }

    function testResturnsCorrectProposalState() public {
        assertEq(
            uint256(voter.state(address(proposer), 1)),
            uint256(IRollCallVoter.ProposalState.Pending),
            "proposal not pending"
        );

        vm.warp(start);
        assertEq(
            uint256(voter.state(address(proposer), 1)),
            uint256(IRollCallVoter.ProposalState.Active),
            "proposal not active"
        );

        vm.warp(end);
        assertEq(
            uint256(voter.state(address(proposer), 1)),
            uint256(IRollCallVoter.ProposalState.Ended)
        );

        vm.expectRevert("rollcall: proposal vote doesnt exist");
        voter.state(address(proposer), 2);
    }
}
