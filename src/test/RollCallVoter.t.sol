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

contract RollCallGovernor {
    RollCallBridge internal bridge;

    mapping(bytes32 => IRollCallGovernor.Proposal) internal proposals;

    constructor(address bridge_) public {
        bridge = RollCallBridge(bridge_);
    }

    function propose(bytes32 id, IRollCallGovernor.Proposal memory p) external {
        proposals[id] = p;
        bridge.propose(id);
    }

    function proposal(bytes32 id)
        public
        view
        virtual
        returns (IRollCallGovernor.Proposal memory)
    {
        return proposals[id];
    }

    function sources() external pure virtual returns (address[] memory) {
        address[] memory s = new address[](1);
        s[0] = 0x7aE1D57b58fA6411F32948314BadD83583eE0e8C;
        return s;
    }

    function slots() external pure virtual returns (bytes32[] memory) {
        bytes32[] memory s = new bytes32[](1);
        s[0] = bytes32(uint256(0));
        return s;
    }

    function finalize(bytes32 id, uint256[3] calldata votes) external virtual {}
}

contract RollCallVoterTester is RollCallVoter {
    constructor(
        string memory name_,
        address cdm_,
        address bridge_
    ) public RollCallVoter(name_, cdm_, bridge_) {}

    function hashTypedDataV4(bytes32 id, uint256 support)
        public
        view
        virtual
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(abi.encode(BALLOT_TYPEHASH, id, support))
            );
    }
}

contract RollCallVoterSetup is DSTest {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    GovernanceERC20 internal token;
    OVM_FakeCrossDomainMessenger internal cdm;
    RollCallBridge internal bridge;
    RollCallVoterTester internal voter;
    RollCallGovernor internal governor;
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

        voter = new RollCallVoterTester(
            "rollcall",
            address(cdm),
            address(bridge)
        );

        governor = new RollCallGovernor(address(bridge));

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
            bytes32(uint256(1)),
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                votesFor: 0,
                votesAgainst: 0,
                votesAbstain: 0,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
                start: ts,
                end: ts + 100,
                executed: false,
                canceled: false
            })
        );
    }

    // function testCantProposeWhenAfterEnd() public {
    //     uint64 ts = uint64(block.timestamp);
    //     vm.warp(block.timestamp + 101);
    //     vm.expectRevert("bridge: proposal end before now");
    //     governor.propose(
    //         1,
    //         IRollCallGovernor.Proposal({
    //             snapshot: block.number,
    //             root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
    //             start: ts,
    //             end: ts + 100,
    //             executed: false,
    //             canceled: false
    //         })
    //     );
    // }
}

contract RollCallVoter_State is RollCallVoterSetup {
    bytes32 private id = bytes32(uint256(1));
    uint64 internal bn = uint64(block.timestamp);
    uint64 internal start = bn + 10;
    uint64 internal end = bn + 100;

    function setUp() public override {
        super.setUp();

        governor.propose(
            bytes32(uint256(1)),
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                votesFor: 0,
                votesAgainst: 0,
                votesAbstain: 0,
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
            uint256(voter.state(address(governor), id)),
            uint256(IRollCallVoter.ProposalState.Pending),
            "proposal not pending"
        );

        blocknumber.setL1BlockNumber(start);
        assertEq(
            uint256(voter.state(address(governor), id)),
            uint256(IRollCallVoter.ProposalState.Active),
            "proposal not active"
        );

        blocknumber.setL1BlockNumber(end);
        assertEq(
            uint256(voter.state(address(governor), id)),
            uint256(IRollCallVoter.ProposalState.Ended)
        );

        voter.finalize(address(governor), id, 1e6);
        assertEq(
            uint256(voter.state(address(governor), id)),
            uint256(IRollCallVoter.ProposalState.Finalized)
        );

        vm.expectRevert("rollcall: proposal vote doesnt exist");
        voter.state(address(governor), bytes32(uint256(2)));
    }
}

contract RollCallVoter_Voting is RollCallVoterSetup {
    bytes32 private id = bytes32(uint256(1));
    uint64 internal bn = uint64(block.number);
    uint64 internal start = bn + 10;
    uint64 internal end = bn + 100;

    function setUp() public override {
        super.setUp();

        blocknumber.setL1BlockNumber(block.number);

        governor.propose(
            bytes32(uint256(1)),
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                votesFor: 0,
                votesAgainst: 0,
                votesAbstain: 0,
                root: hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
                start: start,
                end: end,
                executed: false,
                canceled: false
            })
        );
    }

    function testProposalState() public {
        (bytes32 root_, uint64 start_, uint64 end_, bool finalized_) = voter
            .proposals(address(governor), id);

        assertEq(
            root_,
            hex"1512cc8e18327bfbe120a6298046e5f6fe174155b7a2baceba5adacff6fc5749",
            "root doesnt match"
        );

        assertEq(uint256(start_), uint256(start), "start doesnt match");
        assertEq(uint256(end_), uint256(end), "end doesnt match");
        assertTrue(!finalized_, "finalized doesnt match");
    }

    function testCastVote() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f9076ef90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da01ef28d67169f7361db5189d5a565d05406e39b73f306c402070ee271a07606c2a00b2bf362e791a7b420ed3f2ccdad4337396c18ed871f7233a8d48f7748ff9b36a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa01b1074c304b080df5af49807d9600147779781ace080526272c9cf64b1cfbc26a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a0e0a616bc8f4bd9498c899616cc723dfd8e49fb1c0c570f75dc4bf68d2a6d6f21a011b921a7ba0671ca853176eb477c9eed0ecabe5a96f2c0c7720656627351c66aa03f8397e3c97d4c560a5b1e5a0dff7bc822fafe1a2813eafc5269903bf42a44d580f90211a03e2e05d0555af0b731f4b85734500e3ab4369f194e6cfc9a19066a4f3dcc696ca0a08ac2e89d147187e6a4ef910e8c6557de756220718600e1e2355ef527d84e13a0dcc322f76845acf16373342edec74ff400a5f0565fac36cc3e9080ffb60848d0a0a90b3e47f9fe1b2dd43f12eb0bed6d4e6ff677eda080d93277ea961ec1eacf8ba0b4af7f7edb5d191530130e837c23e7abfadeed2237c357b2bdebc8e52e4c8ce9a09f91561af3edf56078230aadcf497934826f1ddc42c621c9974f1b94e17e4e38a033bfaadadaf01daaa095288b1b412fd67d58f75cfeac32d7e2cb4da51a8c4e11a0f749fad56db633f14aba0136c2d11a9daef5ddbe0eb6c29695f370d58bcc4ee9a01279bf1eaf9756149c8db63f8bbaf213f6810f5f08f31cd9671ca04bf2dd8ca7a064764692bdb2b618f76a33df2489581999322ca9023752ca7b3dc1e5a3b1bcb9a0d45323c2511c3b8e2826280f2381393a5e5a28e0c59d2566023668848343f7b2a0f0805c1825d10ce928002747e5f64836e1ac6d334333922b2d0cb976903492f6a0e64b98a18404773a6fb734278541981963e0ccee03a108d318054b9e554e87d1a0d3a22e54894407b4fa19ecf70ad8b7fef34611de95e392d4d0c89cc4a05c2636a043b320e42c72d0b446342d555970c23350a4ee092ee4ee1770740a39184570aaa07ea7a9babab9920f0888ee096daab4e023bb1940497b5393f59c4818d0276dac80f90211a0b59e4a7021b5908170ae6c0a9c0ee309537dd8ced9967fcc3b7276484813def2a0632775b40d10c8354e6e9850ceb13805b38ef9013c103c76227fb73115bb97eaa00dfea5ae9f9de2b4f2b52bed302059e24abcd9cabfdddd57cdffa2dd3ab0fe5ba0b3674622b3f65635dc588cde4d3ae8c970af51c4e26633579ef3490cd1685f14a0428ad6652dde51b57f14839794fa3e40150a882868a2671a08650a77eb6bf381a0fe10b847711504937c88f350339de028c3554c2a89ceea6a546374ae8c2b3904a0f5817055ef9dda4ed831bfd1bdf5dadf0cf5628934cd01de22b2971b51c80bd3a0627daa0717c8c952f39dcdb0f1080233611d10ff2e65cbec32c709abccbb2661a0a91299e08e2080cea8a99316eebfc165673de9f1df78b136c66c43cfa2591974a0e34bf7636bf24cf00f6b270558f80b3b10d0268297d22cda66c767fc482e0c73a0ddbcd9c49c160c892d78051533d15df32357bf775a4a7e098f787fc3fc61d539a0d1529a51b5d1d2c95c6e832e89caa446b450145dc6c1b357ed3c06b365cd2198a0daa577867396f49956901ac54a2bbd876f0ca8ddd7f365abfd81d4e8f4db02dda0c1d3491683680579a1158563e902b5b42142f63e27542c17c34fc558afe0e13ba0f98d4e726ab20c57c5a481eb678dffeb6f94fdd3f45241a13378417a1a15db8fa01a1527c2a6bd7fec49a0085db66c9a215f4403f733f8a5e1fb8fdb2dd04d409e80f8b180808080a07e431eeb0007cca69d3220b9ae1da0e7be0eba190b8f15c914cc40814d5324dca03c30738990fee2cf2b29589f0b1d53a9b68726a5067d71a1f361845184d0335f808080a036760b66a7d36a9a01969270b95326e9889ea10c106d4cdf796dba6fc1d936db808080a0f1f2bcf80ca5c91e4454b84c340e4089eb395dc995e55e4ef56b29ea1a57db8480a05b66122fed950f85b73218189230ffc9aa391682e19b19015630dc49af9f26cd80f8518080808080a0d87e0b2631f38d6e542df219ee5387e2969dfd016aeaaeb4848c39307b6d2c9a80808080a0d66311d099fa925a071d77db6aac86ff8d856f69992e32cfa66f4cc25ddae321808080808080eb9e34675593a2afa8fe1ff3e09eaa5b961bbb9be0bca4f89c6f3e3b75c558948b8a9a834c203647bcd6cfac";

        vm.startPrank(0xba740c9035fF3c24A69e0df231149c9cd12BAe07);
        assertEq(
            voter.castVote(
                id,
                0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
                address(governor),
                proof,
                1
            ),
            729666447279609190207404,
            "incorrect balance"
        );
    }

    function testCastVoteWithReason() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f9076ef90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da01ef28d67169f7361db5189d5a565d05406e39b73f306c402070ee271a07606c2a00b2bf362e791a7b420ed3f2ccdad4337396c18ed871f7233a8d48f7748ff9b36a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa01b1074c304b080df5af49807d9600147779781ace080526272c9cf64b1cfbc26a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a0e0a616bc8f4bd9498c899616cc723dfd8e49fb1c0c570f75dc4bf68d2a6d6f21a011b921a7ba0671ca853176eb477c9eed0ecabe5a96f2c0c7720656627351c66aa03f8397e3c97d4c560a5b1e5a0dff7bc822fafe1a2813eafc5269903bf42a44d580f90211a03e2e05d0555af0b731f4b85734500e3ab4369f194e6cfc9a19066a4f3dcc696ca0a08ac2e89d147187e6a4ef910e8c6557de756220718600e1e2355ef527d84e13a0dcc322f76845acf16373342edec74ff400a5f0565fac36cc3e9080ffb60848d0a0a90b3e47f9fe1b2dd43f12eb0bed6d4e6ff677eda080d93277ea961ec1eacf8ba0b4af7f7edb5d191530130e837c23e7abfadeed2237c357b2bdebc8e52e4c8ce9a09f91561af3edf56078230aadcf497934826f1ddc42c621c9974f1b94e17e4e38a033bfaadadaf01daaa095288b1b412fd67d58f75cfeac32d7e2cb4da51a8c4e11a0f749fad56db633f14aba0136c2d11a9daef5ddbe0eb6c29695f370d58bcc4ee9a01279bf1eaf9756149c8db63f8bbaf213f6810f5f08f31cd9671ca04bf2dd8ca7a064764692bdb2b618f76a33df2489581999322ca9023752ca7b3dc1e5a3b1bcb9a0d45323c2511c3b8e2826280f2381393a5e5a28e0c59d2566023668848343f7b2a0f0805c1825d10ce928002747e5f64836e1ac6d334333922b2d0cb976903492f6a0e64b98a18404773a6fb734278541981963e0ccee03a108d318054b9e554e87d1a0d3a22e54894407b4fa19ecf70ad8b7fef34611de95e392d4d0c89cc4a05c2636a043b320e42c72d0b446342d555970c23350a4ee092ee4ee1770740a39184570aaa07ea7a9babab9920f0888ee096daab4e023bb1940497b5393f59c4818d0276dac80f90211a0b59e4a7021b5908170ae6c0a9c0ee309537dd8ced9967fcc3b7276484813def2a0632775b40d10c8354e6e9850ceb13805b38ef9013c103c76227fb73115bb97eaa00dfea5ae9f9de2b4f2b52bed302059e24abcd9cabfdddd57cdffa2dd3ab0fe5ba0b3674622b3f65635dc588cde4d3ae8c970af51c4e26633579ef3490cd1685f14a0428ad6652dde51b57f14839794fa3e40150a882868a2671a08650a77eb6bf381a0fe10b847711504937c88f350339de028c3554c2a89ceea6a546374ae8c2b3904a0f5817055ef9dda4ed831bfd1bdf5dadf0cf5628934cd01de22b2971b51c80bd3a0627daa0717c8c952f39dcdb0f1080233611d10ff2e65cbec32c709abccbb2661a0a91299e08e2080cea8a99316eebfc165673de9f1df78b136c66c43cfa2591974a0e34bf7636bf24cf00f6b270558f80b3b10d0268297d22cda66c767fc482e0c73a0ddbcd9c49c160c892d78051533d15df32357bf775a4a7e098f787fc3fc61d539a0d1529a51b5d1d2c95c6e832e89caa446b450145dc6c1b357ed3c06b365cd2198a0daa577867396f49956901ac54a2bbd876f0ca8ddd7f365abfd81d4e8f4db02dda0c1d3491683680579a1158563e902b5b42142f63e27542c17c34fc558afe0e13ba0f98d4e726ab20c57c5a481eb678dffeb6f94fdd3f45241a13378417a1a15db8fa01a1527c2a6bd7fec49a0085db66c9a215f4403f733f8a5e1fb8fdb2dd04d409e80f8b180808080a07e431eeb0007cca69d3220b9ae1da0e7be0eba190b8f15c914cc40814d5324dca03c30738990fee2cf2b29589f0b1d53a9b68726a5067d71a1f361845184d0335f808080a036760b66a7d36a9a01969270b95326e9889ea10c106d4cdf796dba6fc1d936db808080a0f1f2bcf80ca5c91e4454b84c340e4089eb395dc995e55e4ef56b29ea1a57db8480a05b66122fed950f85b73218189230ffc9aa391682e19b19015630dc49af9f26cd80f8518080808080a0d87e0b2631f38d6e542df219ee5387e2969dfd016aeaaeb4848c39307b6d2c9a80808080a0d66311d099fa925a071d77db6aac86ff8d856f69992e32cfa66f4cc25ddae321808080808080eb9e34675593a2afa8fe1ff3e09eaa5b961bbb9be0bca4f89c6f3e3b75c558948b8a9a834c203647bcd6cfac";

        vm.startPrank(0xba740c9035fF3c24A69e0df231149c9cd12BAe07);
        assertEq(
            voter.castVoteWithReason(
                id,
                0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
                address(governor),
                proof,
                1,
                "I love this"
            ),
            729666447279609190207404,
            "incorrect balance"
        );
    }

    function testCastVoteBySig() public {
        id = bytes32(uint256(2));
        uint8 support = 1;

        governor.propose(
            id,
            IRollCallGovernor.Proposal({
                snapshot: block.number,
                votesFor: 0,
                votesAgainst: 0,
                votesAbstain: 0,
                root: hex"2cd6bd673f33197205e0656bf034b073abf0695388a5dcd0e99cd3acddb61d60",
                start: start,
                end: end,
                executed: false,
                canceled: false
            })
        );

        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f907adf90211a0e15b776b5076420f42091e0ea52061a41b0532d661e56b9c650dd43326399154a0a54dd20d0ffa65778c2ac1b10dce946da7145db552f027484164ab49de67d70da0d284d5ef148e1cc2b69ffc5c48e405ea3fd2e80acf27f0693b53314fd7254edda09c687239a4d76e4d59f0dabd7560835b70a2ab557c07855669bf86db5b88d1cea077b763df13fdb49a5e2ee5bbd211f2b855082d4bdefe1bdce41ffd76baea2073a0d8d5593dcd25fb3760ee95079f833b1ebc7a2dc5bed83ea4645adfc2f37d06d5a0c946bdf3c83852f9b9dc9ef491bb7ce81dd3a2cc4400482c6b8ed448b0094aa4a0468ba9adb68ea7dc489eed78ab94007b7cb7a286ceaa8019c96bb354b8daf5c6a089cc7ebaea39fd716c1dc825999d14e14b3d0c4b77c72397a4044c3967a469b8a0b5fbe3d3c4728239bf67660307995d5fcdf2603d42c64b07180ead886537e413a066bda2b81151c0b3810708dbc6682807e9652677c562805602d9aefdf3c88142a087b8e2220b6ac3d43a88e21d795227ec189c533a36e39004a5d08f0853ebc7aca02fbf70d1641ccabc94043d33c3f373bfb51ec522eb78d3dd81abc5d8f099c0cba0aac43707cded10062968a2cd25beb01e58e757648faec4d475dc7674f2ad034ea0106aef93b0f5a0039f5e198cddbda380900ce922333fe9181a691039a392a61aa0a81bd92e037a831b5a760b88c6111c3025bb99281254838eb9bbf714ba40994e80f90211a01dbfcc4dd63c3bec098ff79d1227ab345cbd93502dcdb4af5a8f1dfb3ee177e3a0b0b0eb22b162816c4d2fd5741eb53578322885660fd26d2e6f87027b3f9889c2a0f29afa54770a78330d2b97101b7ddc94ff7e174d0fc9a7c2479b77447601bdb2a087a07bd82c2d5d33500a2b168572128c025ebab522c382e06496b37b652290d3a07f6e3ac56f89dc9c6e43315ed50d7b029d668464ce2de89b3a4cebb706d5e117a0e4ec792e15b18ae9bbd17d36e0657ca90f5419407097eb0ab80b4d3be01f364ba053619f7e92c3cbb79a8bdeaee017d6bb2169bee1d539ddd81fe63d139f89e943a0cac46da8be63d561cfc6db05b8121bde08c0cc4467cde35a5bebbb97d00d6258a02203b3b2216083ca7658534c85116a8757f77e02b3af26b3a78bcd5a0fc97dffa09d4902b161a9d541fb937d8434e6b03d41c74e3b31b144cb8ecab0b40beab5a9a020841a37da3719a471fde97f0d950af67a538ffbec5e1b0d1d0bf015507588e4a07e281ba53fe6f7bb1c8e8cc64c8bf2f4d72815283ae667885bfea98605027d33a098deebdff1fc32c54eb3067318af04cf509e4abd63118e34015c7755d77cc14da0051aaaeb0031efa4cb862bedcf8714dd857d8b57971e1d996b013c7783de3ebca0f0f15cc59d5ab304df04f1d51f799d95e84baa80f8208c2aa3b1690cec17d986a042024d6346497dbdc6d079f9f07203e0cb7f0464c1367bde55600f367269925c80f90211a0ec55eb7e06242c0f2c104c44c8a61cc0f80e5e3c7cd7a8424a6f308490e66d49a0cea611f186649c6dabd93cdf974e6bd9d63b5fbab5c7945e89e9c8c88be9701da0324d3e47145a1b595a8b50301b1ef798c0b2f86291b58298c7306aac976ea0b8a087205b47684283ff9cab00870a56d6be2c1c9e0986397a73e348dea1db64a31da03f292ec73ba53f56eaa1466475a6cbe769fb1e0e53cf2e4e1743cfb6f0617996a0fd70ac923da81c8e679b0c40592644f1afa312f979358845cf3b1d4549c175aba03682422faa6462a555f7151b81d96e5b9a5adf10eff39b3b930023ad4caae3e4a054d3bb7345a7f95a36f4b165a478f79a5a1b7bb07aaa5da9742761423af86cdba028d7d87c11b8af8839479bafb5c3b379c678396e34fb9fcc339dca2bc8e0c0e4a066ec05f265524f37cd5788a372ecc62ac59aff7388b683ea666f8ccacf12252fa0fdf365378f07fdbe8197a5c8f0c90b635777af02699bac0eddac9d009f376f21a00e1e6d976af47bf64f1f6a3da8d0e3fa1c0ab4cfe1f88b2ae5131cacdbe1eafaa09d359570b4f9a1a000ad494db88240f5ec643b5990bb26e2a3f970f06a6c0048a0a53098f59db77a7546c893c026f3203186fc70ca3f8328c02a00bfcebced1471a0c217a0979016898311c6e02a96fb0ec2178cee276cccb34fa810c0ba6bd4d1e6a0b517d8c14d7cf5d0cb4579922bbd9e066be486413d4c68be65d9f8e782ee2d2b80f8f180a0b712316ccb02d7c34774cc6a3ee8b886a020d66f2a72453c9b122c5d7f824f518080a0edd328a9b897318b6d213b9160015f32e84ed85c2c7f1b385a1b108c565c6c0ba02811638e56bf96b0d4c18aaedca3d54260f6c31fd2f8741f95af1904ae0c6d96a01d7c68de1c30ecc0e350881fd128534e02ed2ef5891c963a3701bf3c75463d2c808080a07dc5162880c44a0535ef3c3dd394a1e86fa13b34b5ae0debd4dfff603ae2c0f4a033705ce925197f8022611f67ff31fbe9205868147bd939ce334733b4cb3265028080a0e85ac7eadd78e7c1c5dfd200dc2a9f97fb68c27065720478429fa9232851cfca8080f851808080a0d40b6aa407259fa35f3dc4334beb9cd4e3d519ca74db9136739fa62372e0932b808080808080a08416086f4e463c0974b1250f044d415053edaf998d7f0cc4ea220d90f4c66990808080808080ea9e3fa06f4339708dcda8443119e6fb9292de60c25f1dbda7a6cb5ce27c712f8a8916c4abbebea0100000";

        vm.startPrank(0x2A9479FDCcf018FA417217226495EF64DA8ADDA7);

        bytes32 digest = voter.hashTypedDataV4(id, support);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            0x898010c9b079409192e345307acaa16d132b89feced2e4966d5c4755498557de,
            digest
        );
        assertEq(
            voter.castVoteBySig(
                id,
                0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
                address(governor),
                proof,
                support,
                v,
                r,
                s
            ),
            420000000000000000000,
            "incorrect balance"
        );
    }

    function testCannotCastVoteTwice() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f9076ef90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da01ef28d67169f7361db5189d5a565d05406e39b73f306c402070ee271a07606c2a00b2bf362e791a7b420ed3f2ccdad4337396c18ed871f7233a8d48f7748ff9b36a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa01b1074c304b080df5af49807d9600147779781ace080526272c9cf64b1cfbc26a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a0e0a616bc8f4bd9498c899616cc723dfd8e49fb1c0c570f75dc4bf68d2a6d6f21a011b921a7ba0671ca853176eb477c9eed0ecabe5a96f2c0c7720656627351c66aa03f8397e3c97d4c560a5b1e5a0dff7bc822fafe1a2813eafc5269903bf42a44d580f90211a03e2e05d0555af0b731f4b85734500e3ab4369f194e6cfc9a19066a4f3dcc696ca0a08ac2e89d147187e6a4ef910e8c6557de756220718600e1e2355ef527d84e13a0dcc322f76845acf16373342edec74ff400a5f0565fac36cc3e9080ffb60848d0a0a90b3e47f9fe1b2dd43f12eb0bed6d4e6ff677eda080d93277ea961ec1eacf8ba0b4af7f7edb5d191530130e837c23e7abfadeed2237c357b2bdebc8e52e4c8ce9a09f91561af3edf56078230aadcf497934826f1ddc42c621c9974f1b94e17e4e38a033bfaadadaf01daaa095288b1b412fd67d58f75cfeac32d7e2cb4da51a8c4e11a0f749fad56db633f14aba0136c2d11a9daef5ddbe0eb6c29695f370d58bcc4ee9a01279bf1eaf9756149c8db63f8bbaf213f6810f5f08f31cd9671ca04bf2dd8ca7a064764692bdb2b618f76a33df2489581999322ca9023752ca7b3dc1e5a3b1bcb9a0d45323c2511c3b8e2826280f2381393a5e5a28e0c59d2566023668848343f7b2a0f0805c1825d10ce928002747e5f64836e1ac6d334333922b2d0cb976903492f6a0e64b98a18404773a6fb734278541981963e0ccee03a108d318054b9e554e87d1a0d3a22e54894407b4fa19ecf70ad8b7fef34611de95e392d4d0c89cc4a05c2636a043b320e42c72d0b446342d555970c23350a4ee092ee4ee1770740a39184570aaa07ea7a9babab9920f0888ee096daab4e023bb1940497b5393f59c4818d0276dac80f90211a0b59e4a7021b5908170ae6c0a9c0ee309537dd8ced9967fcc3b7276484813def2a0632775b40d10c8354e6e9850ceb13805b38ef9013c103c76227fb73115bb97eaa00dfea5ae9f9de2b4f2b52bed302059e24abcd9cabfdddd57cdffa2dd3ab0fe5ba0b3674622b3f65635dc588cde4d3ae8c970af51c4e26633579ef3490cd1685f14a0428ad6652dde51b57f14839794fa3e40150a882868a2671a08650a77eb6bf381a0fe10b847711504937c88f350339de028c3554c2a89ceea6a546374ae8c2b3904a0f5817055ef9dda4ed831bfd1bdf5dadf0cf5628934cd01de22b2971b51c80bd3a0627daa0717c8c952f39dcdb0f1080233611d10ff2e65cbec32c709abccbb2661a0a91299e08e2080cea8a99316eebfc165673de9f1df78b136c66c43cfa2591974a0e34bf7636bf24cf00f6b270558f80b3b10d0268297d22cda66c767fc482e0c73a0ddbcd9c49c160c892d78051533d15df32357bf775a4a7e098f787fc3fc61d539a0d1529a51b5d1d2c95c6e832e89caa446b450145dc6c1b357ed3c06b365cd2198a0daa577867396f49956901ac54a2bbd876f0ca8ddd7f365abfd81d4e8f4db02dda0c1d3491683680579a1158563e902b5b42142f63e27542c17c34fc558afe0e13ba0f98d4e726ab20c57c5a481eb678dffeb6f94fdd3f45241a13378417a1a15db8fa01a1527c2a6bd7fec49a0085db66c9a215f4403f733f8a5e1fb8fdb2dd04d409e80f8b180808080a07e431eeb0007cca69d3220b9ae1da0e7be0eba190b8f15c914cc40814d5324dca03c30738990fee2cf2b29589f0b1d53a9b68726a5067d71a1f361845184d0335f808080a036760b66a7d36a9a01969270b95326e9889ea10c106d4cdf796dba6fc1d936db808080a0f1f2bcf80ca5c91e4454b84c340e4089eb395dc995e55e4ef56b29ea1a57db8480a05b66122fed950f85b73218189230ffc9aa391682e19b19015630dc49af9f26cd80f8518080808080a0d87e0b2631f38d6e542df219ee5387e2969dfd016aeaaeb4848c39307b6d2c9a80808080a0d66311d099fa925a071d77db6aac86ff8d856f69992e32cfa66f4cc25ddae321808080808080eb9e34675593a2afa8fe1ff3e09eaa5b961bbb9be0bca4f89c6f3e3b75c558948b8a9a834c203647bcd6cfac";

        vm.startPrank(0xba740c9035fF3c24A69e0df231149c9cd12BAe07);
        voter.castVote(
            id,
            0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
            address(governor),
            proof,
            1
        );

        vm.expectRevert("rollcall: already voted");
        voter.castVote(
            id,
            0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
            address(governor),
            proof,
            1
        );
    }

    function testCannotCastVoteWithValidProofFromEarlyBlockHeight() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f9076ef90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da066281b02a1c6591c16778f8bf42581c2a527c96e73cbd8c19392b4662003e44fa0e42e3e317beca4f12dca9a4c88592016b6392eb50195dae824ffb8c9b4f88c24a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa0295797ad07f23e13b34d3152d870c45edfae6f3b6b9c7258d9744e01eab59f37a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a03fcc6f9b0f841c9bf0dde7c0ae51e71666305f81aa46d6b0f8200018c958d942a06ecd09aa3e2b3b87127f6cf0129ceb03cde6519c4cecbcd82cc437b7da37454da0971cd2b4fc8bbbc831a86ca05a3e24579446654db6fc57525946f6943b00e77080f90211a03e2e05d0555af0b731f4b85734500e3ab4369f194e6cfc9a19066a4f3dcc696ca0a08ac2e89d147187e6a4ef910e8c6557de756220718600e1e2355ef527d84e13a0dcc322f76845acf16373342edec74ff400a5f0565fac36cc3e9080ffb60848d0a0a90b3e47f9fe1b2dd43f12eb0bed6d4e6ff677eda080d93277ea961ec1eacf8ba0b4af7f7edb5d191530130e837c23e7abfadeed2237c357b2bdebc8e52e4c8ce9a09f91561af3edf56078230aadcf497934826f1ddc42c621c9974f1b94e17e4e38a033bfaadadaf01daaa095288b1b412fd67d58f75cfeac32d7e2cb4da51a8c4e11a0f749fad56db633f14aba0136c2d11a9daef5ddbe0eb6c29695f370d58bcc4ee9a01279bf1eaf9756149c8db63f8bbaf213f6810f5f08f31cd9671ca04bf2dd8ca7a010348e5c501993223df5653f23e6a18f71f99dec9d295260c4f4348988cc119ba0d45323c2511c3b8e2826280f2381393a5e5a28e0c59d2566023668848343f7b2a0f0805c1825d10ce928002747e5f64836e1ac6d334333922b2d0cb976903492f6a0e64b98a18404773a6fb734278541981963e0ccee03a108d318054b9e554e87d1a0d3a22e54894407b4fa19ecf70ad8b7fef34611de95e392d4d0c89cc4a05c2636a043b320e42c72d0b446342d555970c23350a4ee092ee4ee1770740a39184570aaa07ea7a9babab9920f0888ee096daab4e023bb1940497b5393f59c4818d0276dac80f90211a0b59e4a7021b5908170ae6c0a9c0ee309537dd8ced9967fcc3b7276484813def2a0632775b40d10c8354e6e9850ceb13805b38ef9013c103c76227fb73115bb97eaa00dfea5ae9f9de2b4f2b52bed302059e24abcd9cabfdddd57cdffa2dd3ab0fe5ba0b3674622b3f65635dc588cde4d3ae8c970af51c4e26633579ef3490cd1685f14a0428ad6652dde51b57f14839794fa3e40150a882868a2671a08650a77eb6bf381a0fe10b847711504937c88f350339de028c3554c2a89ceea6a546374ae8c2b3904a0f5817055ef9dda4ed831bfd1bdf5dadf0cf5628934cd01de22b2971b51c80bd3a0627daa0717c8c952f39dcdb0f1080233611d10ff2e65cbec32c709abccbb2661a0a91299e08e2080cea8a99316eebfc165673de9f1df78b136c66c43cfa2591974a0e34bf7636bf24cf00f6b270558f80b3b10d0268297d22cda66c767fc482e0c73a0ddbcd9c49c160c892d78051533d15df32357bf775a4a7e098f787fc3fc61d539a0d1529a51b5d1d2c95c6e832e89caa446b450145dc6c1b357ed3c06b365cd2198a0daa577867396f49956901ac54a2bbd876f0ca8ddd7f365abfd81d4e8f4db02dda0c1d3491683680579a1158563e902b5b42142f63e27542c17c34fc558afe0e13ba0f98d4e726ab20c57c5a481eb678dffeb6f94fdd3f45241a13378417a1a15db8fa01a1527c2a6bd7fec49a0085db66c9a215f4403f733f8a5e1fb8fdb2dd04d409e80f8b180808080a07e431eeb0007cca69d3220b9ae1da0e7be0eba190b8f15c914cc40814d5324dca03c30738990fee2cf2b29589f0b1d53a9b68726a5067d71a1f361845184d0335f808080a036760b66a7d36a9a01969270b95326e9889ea10c106d4cdf796dba6fc1d936db808080a0f1f2bcf80ca5c91e4454b84c340e4089eb395dc995e55e4ef56b29ea1a57db8480a05b66122fed950f85b73218189230ffc9aa391682e19b19015630dc49af9f26cd80f8518080808080a0d87e0b2631f38d6e542df219ee5387e2969dfd016aeaaeb4848c39307b6d2c9a80808080a0d66311d099fa925a071d77db6aac86ff8d856f69992e32cfa66f4cc25ddae321808080808080eb9e34675593a2afa8fe1ff3e09eaa5b961bbb9be0bca4f89c6f3e3b75c558948b8a9a834c203647bcd6cfac";
        vm.startPrank(0xba740c9035fF3c24A69e0df231149c9cd12BAe07);
        vm.expectRevert("root hash mismatch");
        voter.castVote(
            id,
            0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
            address(governor),
            proof,
            1
        );
    }

    function testCannotCastVoteWithZeroWeight() public {
        blocknumber.setL1BlockNumber(start);
        bytes
            memory proof = hex"f906eff90211a0f1dce22999ba5391561aa11e20c7e82b82a1d2dab1dfa167f2661ad1f1510798a0bac558f851bc499047b46b4411fa4eb3d7b041b6340cd6d5a8feb4e587645625a0dd7f82cf77647317ed5091e26875d4a0dda8394e7749378d0e469384bfa51b4da01ef28d67169f7361db5189d5a565d05406e39b73f306c402070ee271a07606c2a00b2bf362e791a7b420ed3f2ccdad4337396c18ed871f7233a8d48f7748ff9b36a02a4ab95a3c3a7a28147e989fc3fd6c262deb037b7827615906d60bffa953400ea000d0989e26782e827164b10bf89cc6125521132770b9af5a4123eb35cbdd3eb4a012843cc6e97e556eb2df4ca42249a60958a1fca6eb6e0ec6ffca4eaca9172ab7a0d9a7f97235f5e5965784c89ac18aa435c5e2c7c6d3433224a37ebaf420ffbe2ea0b3ad7d9d798db58616b97df20763e91c21656ecc8be9273eef6ef22a2306f762a0772e71cb1058f99f0a3422dcc9f98aae9e0b54a36e25178a7022494eaa74548aa01b1074c304b080df5af49807d9600147779781ace080526272c9cf64b1cfbc26a0473e62fca02434841110ea7e07072fbc2c55bb16222d0a4c53c74fb7fb7627a1a0e0a616bc8f4bd9498c899616cc723dfd8e49fb1c0c570f75dc4bf68d2a6d6f21a011b921a7ba0671ca853176eb477c9eed0ecabe5a96f2c0c7720656627351c66aa03f8397e3c97d4c560a5b1e5a0dff7bc822fafe1a2813eafc5269903bf42a44d580f90211a00ddd47aca8a52ed5cb832743a7b044e2830e40b9df7e6c17dcf1445f41d82c40a01bbe41ecd918a4c3678ace3bf38589a453dfe9a395ab8e26ee510ddb0154ed79a04839d65a2682cc2be3003ddcb444ec898076a551d6f08e1d999ed483c77cc0d2a067d694eb9fe50da40bf5c4a17e6d1d1a55e1e8304110537a91e5d504c248cde0a0516edc989a5e01f85968089cac319412b6be2abf97f3e9d4296927715602244aa08bdbec8622aad1406c7d40424432eb18cf42142996acc25844fe8877c8c823aaa089d4f55b3559390e4ad6a175601c2c51adab6dd4f188ebc1bc4b38d95707b8d5a02dd9cdd56a322ccd0ad5f4b210e72dbbfc4c18f802911d031b9cab606251a997a05224f83c063c9f886a188fbcf4eed53807a0313962b3439bce28f0a65fa59976a054ddaad037f6087e163465371af0a336067f8611567304ca85add6b2b6a4a3f0a00caea4354b879fdddf05cc762eccf51816ce22c07dc334b7f9e36150103915d9a0967148f40c88ebd32530324d2b14e07ff3746d84f9e3ac05f8b37521958ad5eca097d7a0be7120a7e47d34ef25caf567807598b29a60e12b8df5af0bfaabcbde65a0e5a76b7bb15f97cfd52f174fa31e57bcb2cca1804227a19e6274b311c8a578d1a0e98acf2290854362940f0d89272424e6fa74ad6c79427ace7c95e5ac42bf9513a00f9938c4e87531836b261e8c420430f6d5a02d68dbba4008cc317c6d469507b580f901f180a03f2a7263da4053a98af3fb8d043d5ee9784de21df810e3084e7bd053cb467e11a0feb537635512b37d6039936d872de4d08d0ccfc058d0d2c5094cab7e5b18d9d4a091f14a617df569e4e4b112ef7a2726e94d91bc30507db23534c4d247f06614b5a0fb3e7d374158b5eb572d83daed2c5fd43040aabeaf0808db1ebaee69ba9f6705a0a52afb04cd379d5a76c7848078927037ee7ac6efd8bd7a9afe85ef25a83f5314a0109d30b2de07780942cb3733a4854da0ba26d0f7b45199b957705fcb6d8dbca8a0fec4e10b9e63b82528e1ef120cdb42db9b85bae30252c5ee0d2c72834cd3508aa0bddc6c0283938badb286044061618da335095fefd66acc69bcbf7fab9c2479d7a051dbdb3a7c3375317abc12425d6c154a0beb3e7e6f97c4ddedf68ebc3c6ef9dfa0672d9298edb22c87555a83579a8812c08d9a1aa0d7041b4e239b851353a1df18a0a41abd6014fd4133b6530115d4fdd6422e3a4cc4c1497592b8dbf9ad8aafba0ba0d471bc803411b4b8179ebd54e3404241049991778562fc7418a7310f7ffb12b8a099c072bacf944c81718249e16723f4d622d72bfaa24e803acbfc42d44599e9f8a00dad326ff26f61ae027f92b308810e7ac77305fdf4bd1a4f59fdace5c52fde92a0241ab8f092cbc2d7f72bac14d508e8d80a230145fe5c0c7843ce7cfc27cd9a6580f8d180a0e7b34d8daea3bdca1ceb3632b406545cfca407e0f682c976e0ea6a433e79d60f80a00da9e04822a6a21dc1f0ceb39ad6398f1f6acb2f146537ff14183f5a32557215a06a09a5b2810dfb997a998d6b4297e814cd9a446ef531fab307e713efcfc83a70808080a0816941c03fe73edfacc1dcc56c1e8862b024459e7c7b7384b1247eac6900e2198080a049b27da5deb84701a42dddc6089173e3907856972861093eecda5b7b0fc890518080a0b490f9b1dc24759462ba807f02d54d420bb6ac576f8f1b616f5c13f03a041e788080";
        vm.startPrank(address(0));
        vm.expectRevert("voter: balance doesnt exist");
        voter.castVote(
            id,
            0x7aE1D57b58fA6411F32948314BadD83583eE0e8C,
            address(governor),
            proof,
            1
        );
    }
}
