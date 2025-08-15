// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title OptionsBuilderHelper
 * @notice Helper contract to build LayerZero options for compose messages
 */
contract OptionsBuilderHelper {
    using OptionsBuilder for bytes;

    /**
     * @notice Build options for compose message execution
     * @param lzReceiveGas Gas limit for lzReceive function
     * @param lzComposeGas Gas limit for lzCompose function
     * @return options Encoded options bytes
     */
    function buildComposeOptions(
        uint128 lzReceiveGas,
        uint128 lzComposeGas
    ) external pure returns (bytes memory options) {
        options = OptionsBuilder.newOptions()
            .addExecutorLzReceiveOption(lzReceiveGas, 0)        // Token transfer + compose queuing
            .addExecutorLzComposeOption(0, lzComposeGas, 0);    // Composer contract execution
    }

    /**
     * @notice Build default options for compose message execution
     * @return options Encoded options bytes with default gas limits
     */
    function buildDefaultComposeOptions() external pure returns (bytes memory options) {
        return buildComposeOptions(65000, 50000);
    }

    /**
     * @notice Build custom options with additional parameters
     * @param lzReceiveGas Gas limit for lzReceive function
     * @param lzReceiveValue Native value for lzReceive
     * @param lzComposeIndex Compose index (usually 0)
     * @param lzComposeGas Gas limit for lzCompose function
     * @param lzComposeValue Native value for lzCompose
     * @return options Encoded options bytes
     */
    function buildCustomComposeOptions(
        uint128 lzReceiveGas,
        uint128 lzReceiveValue,
        uint16 lzComposeIndex,
        uint128 lzComposeGas,
        uint128 lzComposeValue
    ) external pure returns (bytes memory options) {
        options = OptionsBuilder.newOptions()
            .addExecutorLzReceiveOption(lzReceiveGas, lzReceiveValue)
            .addExecutorLzComposeOption(lzComposeIndex, lzComposeGas, lzComposeValue);
    }
}
