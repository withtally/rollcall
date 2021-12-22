// SPDX-License-Identifier: Unlicense
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {Vm} from "./lib/Vm.sol";
import {OVM_FakeL1BlockNumber} from "./OVM_FakeL1BlockNumber.sol";
import {OVM_FakeCrossDomainMessenger} from "./OVM_FakeCrossDomainMessenger.sol";
import {Lib_PredeployAddresses} from "../lib/Lib_PredeployAddresses.sol";

import {RollCallBridge} from "../RollCallBridge.sol";
import {IRollCallGovernor} from "../interfaces/IRollCallGovernor.sol";
import {IRollCallVoter} from "../interfaces/IRollCallVoter.sol";
import {RollCallVoter} from "../RollCallVoter.sol";

contract GovernanceERC20 is ERC20 {
    constructor() public ERC20("Rollcall", "ROLLCALL") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RollCallProposer {
    RollCallBridge internal bridge;

    mapping(uint256 => IRollCallGovernor.Proposal) internal proposals;

    constructor(address bridge_) public {
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

    function token() external pure virtual returns (address) {
        return 0x7aE1D57b58fA6411F32948314BadD83583eE0e8C;
    }

    function slot() external pure virtual returns (bytes32) {
        return
            0x9f9913eb00db1630cca84a7a1706a631e771278c4f0ef0d2bdce02e5911598b6;
    }
}

contract RollCallVoterSetup is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    GovernanceERC20 internal token;
    OVM_FakeCrossDomainMessenger internal cdm;
    RollCallBridge internal bridge;
    RollCallVoter internal voter;
    RollCallProposer internal governor;
    OVM_FakeL1BlockNumber internal blocknumber;

    function setUp() public virtual {
        blocknumber = OVM_FakeL1BlockNumber(
            Lib_PredeployAddresses.L1_BLOCK_NUMBER
        );
        vm.etch(
            Lib_PredeployAddresses.L1_BLOCK_NUMBER,
            type(OVM_FakeL1BlockNumber).runtimeCode
        );

        cdm = new OVM_FakeCrossDomainMessenger();

        bridge = new RollCallBridge(cdm);

        voter = new RollCallVoter("rollcall", address(cdm), address(bridge));

        governor = new RollCallProposer(address(bridge));

        bridge.setVoter(address(voter));
    }
}

contract RollCallVoterProposing is RollCallVoterSetup {
    function setUp() public override {
        super.setUp();
    }

    function testCanPropose() public {
        uint64 ts = uint64(block.timestamp);
        governor.propose(
            1,
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
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
        governor.propose(
            1,
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
                start: ts,
                end: ts + 100,
                executed: false,
                canceled: false
            })
        );
    }
}

contract RollCallVoterState is RollCallVoterSetup {
    uint64 internal bn = uint64(block.timestamp);
    uint64 internal start = bn + 10;
    uint64 internal end = bn + 100;

    function setUp() public override {
        super.setUp();

        governor.propose(
            1,
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
                start: start,
                end: end,
                executed: false,
                canceled: false
            })
        );
    }

    function testReturnsCorrectProposalState() public {
        assertEq(
            uint256(voter.state(address(governor), 1)),
            uint256(IRollCallVoter.ProposalState.Pending),
            "proposal not pending"
        );

        blocknumber.setL1BlockNumber(start);
        assertEq(
            uint256(voter.state(address(governor), 1)),
            uint256(IRollCallVoter.ProposalState.Active),
            "proposal not active"
        );

        blocknumber.setL1BlockNumber(end);
        assertEq(
            uint256(voter.state(address(governor), 1)),
            uint256(IRollCallVoter.ProposalState.Ended)
        );

        vm.expectRevert("rollcall: proposal vote doesnt exist");
        voter.state(address(governor), 2);
    }
}

contract RollCallVoter_Voting is RollCallVoterSetup {
    uint64 internal bn = uint64(block.number);
    uint64 internal start = bn + 10;
    uint64 internal end = bn + 100;

    function setUp() public override {
        super.setUp();

        blocknumber.setL1BlockNumber(block.number);

        governor.propose(
            1,
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
                start: start,
                end: end,
                executed: false,
                canceled: false
            })
        );
    }

    function testProposalState() public {
        (
            address token_,
            bytes32 root_,
            bytes32 slot_,
            uint64 start_,
            uint64 end_,
            bool finalized_
        ) = voter.proposals(address(governor), 1);
        assertEq(
            token_,
            0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
            "token doesnt match"
        );

        assertEq(
            root_,
            hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
            "root doesnt match"
        );

        assertEq(
            slot_,
            hex"9f9913eb00db1630cca84a7a1706a631e771278c4f0ef0d2bdce02e5911598b6",
            "slot doesnt match"
        );

        assertEq(uint256(start_), uint256(start), "start doesnt match");
        assertEq(uint256(end_), uint256(end), "end doesnt match");
        assertTrue(!finalized_, "finalized doesnt match");
    }

    function testCastVote() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f9076ef90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da01ef28d67169f7361db5189d5a565d05406e39b73f306c402070ee271a07606c2a00b2bf362e791a7b420ed3f2ccdad4337396c18ed871f7233a8d48f7748ff9b36a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa01b1074c304b080df5af49807d9600147779781ace080526272c9cf64b1cfbc26a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a0e0a616bc8f4bd9498c899616cc723dfd8e49fb1c0c570f75dc4bf68d2a6d6f21a011b921a7ba0671ca853176eb477c9eed0ecabe5a96f2c0c7720656627351c66aa03f8397e3c97d4c560a5b1e5a0dff7bc822fafe1a2813eafc5269903bf42a44d580f90211a03e2e05d0555af0b731f4b85734500e3ab4369f194e6cfc9a19066a4f3dcc696ca0a08ac2e89d147187e6a4ef910e8c6557de756220718600e1e2355ef527d84e13a0dcc322f76845acf16373342edec74ff400a5f0565fac36cc3e9080ffb60848d0a0a90b3e47f9fe1b2dd43f12eb0bed6d4e6ff677eda080d93277ea961ec1eacf8ba0b4af7f7edb5d191530130e837c23e7abfadeed2237c357b2bdebc8e52e4c8ce9a09f91561af3edf56078230aadcf497934826f1ddc42c621c9974f1b94e17e4e38a033bfaadadaf01daaa095288b1b412fd67d58f75cfeac32d7e2cb4da51a8c4e11a0f749fad56db633f14aba0136c2d11a9daef5ddbe0eb6c29695f370d58bcc4ee9a01279bf1eaf9756149c8db63f8bbaf213f6810f5f08f31cd9671ca04bf2dd8ca7a064764692bdb2b618f76a33df2489581999322ca9023752ca7b3dc1e5a3b1bcb9a0d45323c2511c3b8e2826280f2381393a5e5a28e0c59d2566023668848343f7b2a0f0805c1825d10ce928002747e5f64836e1ac6d334333922b2d0cb976903492f6a0e64b98a18404773a6fb734278541981963e0ccee03a108d318054b9e554e87d1a0d3a22e54894407b4fa19ecf70ad8b7fef34611de95e392d4d0c89cc4a05c2636a043b320e42c72d0b446342d555970c23350a4ee092ee4ee1770740a39184570aaa07ea7a9babab9920f0888ee096daab4e023bb1940497b5393f59c4818d0276dac80f90211a0b59e4a7021b5908170ae6c0a9c0ee309537dd8ced9967fcc3b7276484813def2a0632775b40d10c8354e6e9850ceb13805b38ef9013c103c76227fb73115bb97eaa00dfea5ae9f9de2b4f2b52bed302059e24abcd9cabfdddd57cdffa2dd3ab0fe5ba0b3674622b3f65635dc588cde4d3ae8c970af51c4e26633579ef3490cd1685f14a0428ad6652dde51b57f14839794fa3e40150a882868a2671a08650a77eb6bf381a0fe10b847711504937c88f350339de028c3554c2a89ceea6a546374ae8c2b3904a0f5817055ef9dda4ed831bfd1bdf5dadf0cf5628934cd01de22b2971b51c80bd3a0627daa0717c8c952f39dcdb0f1080233611d10ff2e65cbec32c709abccbb2661a0a91299e08e2080cea8a99316eebfc165673de9f1df78b136c66c43cfa2591974a0e34bf7636bf24cf00f6b270558f80b3b10d0268297d22cda66c767fc482e0c73a0ddbcd9c49c160c892d78051533d15df32357bf775a4a7e098f787fc3fc61d539a0d1529a51b5d1d2c95c6e832e89caa446b450145dc6c1b357ed3c06b365cd2198a0daa577867396f49956901ac54a2bbd876f0ca8ddd7f365abfd81d4e8f4db02dda0c1d3491683680579a1158563e902b5b42142f63e27542c17c34fc558afe0e13ba0f98d4e726ab20c57c5a481eb678dffeb6f94fdd3f45241a13378417a1a15db8fa01a1527c2a6bd7fec49a0085db66c9a215f4403f733f8a5e1fb8fdb2dd04d409e80f8b180808080a07e431eeb0007cca69d3220b9ae1da0e7be0eba190b8f15c914cc40814d5324dca03c30738990fee2cf2b29589f0b1d53a9b68726a5067d71a1f361845184d0335f808080a036760b66a7d36a9a01969270b95326e9889ea10c106d4cdf796dba6fc1d936db808080a0f1f2bcf80ca5c91e4454b84c340e4089eb395dc995e55e4ef56b29ea1a57db8480a05b66122fed950f85b73218189230ffc9aa391682e19b19015630dc49af9f26cd80f8518080808080a0d87e0b2631f38d6e542df219ee5387e2969dfd016aeaaeb4848c39307b6d2c9a80808080a0d66311d099fa925a071d77db6aac86ff8d856f69992e32cfa66f4cc25ddae321808080808080eb9e34675593a2afa8fe1ff3e09eaa5b961bbb9be0bca4f89c6f3e3b75c558948b8a9a834c203647bcd6cfac";

        assertEq(
            voter.castVote(1, address(governor), proof, 1),
            729666447279609190207404,
            "incorrect balance"
        );
    }
}
