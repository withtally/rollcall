// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {iOVM_FakeCrossDomainMessenger} from "./iOVM_FakeCrossDomainMessenger.sol";
import {Hevm} from "./lib/Hevm.sol";

import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallGovernor} from "../interfaces/IRollCallGovernor.sol";
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
    Hevm internal hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
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

    function testFailCantProposeWhenAfterEnd() public {
        uint64 ts = uint64(block.timestamp);
        hevm.warp(block.timestamp + 101);
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
