// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import {Lib_PredeployAddresses} from "forge-optimism/lib/Lib_PredeployAddresses.sol";
import {L2ERC20Votes} from "./L2ERC20Votes.sol";
import {IL2VotingERC20} from "./IL2VotingERC20.sol";

contract L2VotingERC20 is ERC20, ERC20Permit, L2ERC20Votes, IL2VotingERC20 {
    address public l1Token;
    address public l2Bridge;

    /**
     * @param _l1Token Address of the corresponding L1 token.
     * @param _name ERC20 name.
     * @param _symbol ERC20 symbol.
     */
    constructor(
        address _l1Token,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        l1Token = _l1Token;
        l2Bridge = Lib_PredeployAddresses.L2_STANDARD_BRIDGE;
    }

    modifier onlyL2Bridge() {
        require(msg.sender == l2Bridge, "Only L2 Bridge can mint and burn");
        _;
    }

    // slither-disable-next-line external-function
    function supportsInterface(bytes4 _interfaceId) public pure returns (bool) {
        bytes4 firstSupportedInterface = bytes4(
            keccak256("supportsInterface(bytes4)")
        ); // ERC165
        bytes4 secondSupportedInterface = IL2VotingERC20.l1Token.selector ^
            IL2VotingERC20.mint.selector ^
            IL2VotingERC20.burn.selector;
        return
            _interfaceId == firstSupportedInterface ||
            _interfaceId == secondSupportedInterface;
    }

    // slither-disable-next-line external-function
    function mint(address _to, uint256 _amount) public virtual onlyL2Bridge {
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    // slither-disable-next-line external-function
    function burn(address _from, uint256 _amount) public virtual onlyL2Bridge {
        _burn(_from, _amount);

        emit Burn(_from, _amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, L2ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, L2ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, L2ERC20Votes)
    {
        super._burn(account, amount);
    }
}
