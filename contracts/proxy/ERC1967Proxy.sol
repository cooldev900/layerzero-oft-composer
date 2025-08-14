// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ERC1967ProxyWrapper
 * @notice A simple wrapper around OpenZeppelin's ERC1967Proxy to make it deployable via Hardhat
 */
contract ERC1967ProxyWrapper is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}
