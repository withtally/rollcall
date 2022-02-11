// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC721Holder} from "openzeppelin-contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Treasury is ERC721Holder, ERC1155Holder {
    error UNAUTHORIZED();
    error UNDERLYING_CONTRACT_REVERTED();

    address public admin;
    address public pendingAdmin;

    constructor() {
        admin = msg.sender;
    }

    /**
     * @dev Set the pending admin for the treasury;
     */
    function setPendingAdmin(address _pendingAdmin) external onlyAdmin {
        pendingAdmin = _pendingAdmin;
    }

    /**
     * @dev Accept a pending admin for the treasury;
     */
    function acceptPendingAdmin() external {
        if (msg.sender != pendingAdmin) {
            revert UNAUTHORIZED();
        }

        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    /**
     * @dev Execute a call as the treasury.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyAdmin {
        (bool success, ) = target.call{value: value}(data);
        if (!success) {
            revert UNDERLYING_CONTRACT_REVERTED();
        }
    }

    /**
     * @dev Allow contract to receive/hold eth.
     */
    receive() external payable {}

    modifier onlyAdmin() {
        if (msg.sender != admin && msg.sender != address(this)) {
            revert UNAUTHORIZED();
        }
        _;
    }
}
