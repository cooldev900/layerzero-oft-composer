// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title ComposeMsg
 * @notice Library for encoding and decoding compose messages with different message types
 */
library ComposeMsg {
    /// @notice Message types for compose operations
    enum MessageType {
        CROSS_CHAIN_SEND, // Send tokens to a recipient on a different chain
        BURNT // Burn tokens on the source chain
    }

    /// @notice Structure for compose message data
    struct ComposeData {
        address recipient; // The recipient address
        MessageType messageType; // The type of message
        bytes additionalData; // Additional data (e.g., amount for BURNT messages)
    }

    /**
     * @notice Encodes compose data into bytes
     * @param recipient The recipient address
     * @param messageType The type of message
     * @param additionalData Additional data (e.g., amount for BURNT messages)
     * @return Encoded compose message
     */
    function encode(
        address recipient,
        MessageType messageType,
        bytes memory additionalData
    ) internal pure returns (bytes memory) {
        return abi.encode(recipient, messageType, additionalData);
    }

    /**
     * @notice Encodes compose data for CROSS_CHAIN_SEND (no additional data needed)
     * @param recipient The recipient address
     * @return Encoded compose message
     */
    function encodeCrossChainSend(address recipient) internal pure returns (bytes memory) {
        return encode(recipient, MessageType.CROSS_CHAIN_SEND, "");
    }

    /**
     * @notice Encodes compose data for BURNT message with amount
     * @param recipient The recipient address
     * @param amount The amount that was burnt
     * @return Encoded compose message
     */
    function encodeBurnt(address recipient, uint256 amount) internal pure returns (bytes memory) {
        return encode(recipient, MessageType.BURNT, abi.encode(amount));
    }

    /**
     * @notice Decodes compose message into structured data
     * @param data The encoded compose message
     * @return composeData The decoded compose data
     */
    function decode(bytes memory data) internal pure returns (ComposeData memory composeData) {
        (composeData.recipient, composeData.messageType, composeData.additionalData) = abi.decode(
            data,
            (address, MessageType, bytes)
        );
    }

    /**
     * @notice Extracts recipient address from encoded compose message
     * @param data The encoded compose message
     * @return recipient The recipient address
     */
    function getRecipient(bytes memory data) internal pure returns (address recipient) {
        (recipient, , ) = abi.decode(data, (address, MessageType, bytes));
    }

    /**
     * @notice Extracts message type from encoded compose message
     * @param data The encoded compose message
     * @return messageType The message type
     */
    function getMessageType(bytes memory data) internal pure returns (MessageType messageType) {
        (, messageType, ) = abi.decode(data, (address, MessageType, bytes));
    }

    /**
     * @notice Extracts additional data from encoded compose message
     * @param data The encoded compose message
     * @return additionalData The additional data
     */
    function getAdditionalData(bytes memory data) internal pure returns (bytes memory additionalData) {
        (, , additionalData) = abi.decode(data, (address, MessageType, bytes));
    }

    /**
     * @notice Extracts amount from BURNT message additional data
     * @param data The encoded compose message (must be BURNT type)
     * @return amount The burnt amount
     */
    function getBurntAmount(bytes memory data) internal pure returns (uint256 amount) {
        (, MessageType messageType, bytes memory additionalData) = abi.decode(
            data,
            (address, MessageType, bytes)
        );
        require(messageType == MessageType.BURNT, "ComposeMsg: not a BURNT message");
        amount = abi.decode(additionalData, (uint256));
    }

    /**
     * @notice Checks if the message is of a specific type
     * @param data The encoded compose message
     * @param expectedType The expected message type
     * @return True if message type matches
     */
    function isMessageType(bytes memory data, MessageType expectedType) internal pure returns (bool) {
        return getMessageType(data) == expectedType;
    }
}
