// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { AlphaOFT } from "../AlphaOFT.sol";

// @dev WARNING: This is for testing purposes only
contract MyOFTMock is AlphaOFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) AlphaOFT(_name, _symbol, _lzEndpoint, _delegate) {}

    function mint(address _to, uint256 _amount) public override {
        _mint(_to, _amount);
    }
}
