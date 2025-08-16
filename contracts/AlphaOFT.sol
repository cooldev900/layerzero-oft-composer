// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { SendParam, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ComposeMsg } from "./libraries/ComposeMsg.sol";

contract AlphaOFT is OFT {
    /// @notice Mapping of destination endpoint ID to cross-chain manager contract address
    mapping(uint32 => address) public crossChainManagers;
    
    /// @notice Events
    event CrossChainManagerUpdated(uint32 indexed dstEid, address indexed oldManager, address indexed newManager);
    event CrossChainSendInitiated(address indexed recipient, uint256 amount, uint32 dstEid);
    
    /// @notice Errors
    error ZeroAddress();
    error InvalidEndpointId();
    error NoCrossChainManager();
    error NoPeerConfigured();

    /// @notice Modifier to validate destination endpoint and peer configuration
    modifier validDestination(uint32 _dstEid) {
        if (_dstEid == 0) revert InvalidEndpointId();
        if (peers[_dstEid] == bytes32(0)) revert NoPeerConfigured();
        if (crossChainManagers[_dstEid] == address(0)) revert NoCrossChainManager();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}

    function mint(address _to, uint256 _amount) external onlyOwner virtual {
        _mint(_to, _amount);
    }

    function sendComposed(
        address _to, 
        uint256 _amount,
        uint32 _dstEid,
        ComposeMsg.MessageType _messageType,
        bool _payInLzToken,
        bytes calldata _extraOptions
    ) external payable onlyOwner virtual {
        _sendComposed(_to, _amount, _dstEid, _messageType, _payInLzToken, _extraOptions);
    }

    /**
     * @notice Set the cross-chain manager contract address for a specific destination chain
     * @param _dstEid The destination endpoint ID
     * @param _crossChainManager The cross-chain manager contract address
     */
    function setCrossChainManager(uint32 _dstEid, address _crossChainManager) external onlyOwner {
        if (_dstEid == 0) revert InvalidEndpointId();
        if (_crossChainManager == address(0)) revert ZeroAddress();
        
        address oldManager = crossChainManagers[_dstEid];
        crossChainManagers[_dstEid] = _crossChainManager;
        
        emit CrossChainManagerUpdated(_dstEid, oldManager, _crossChainManager);
    }

    /**
     * @notice Quote the cost of sending tokens cross-chain with compose message
     * @param _to The recipient address
     * @param _amount The amount to send
     * @param _dstEid The destination endpoint ID
     * @param _messageType The type of compose message (CROSS_CHAIN_SEND or BURNT)
     * @param _payInLzToken Whether to pay in LZ tokens
     * @param _extraOptions Additional LayerZero options
     * @return msgFee The messaging fee required for the cross-chain send
     */
    function quoteSendComposed(
        address _to,
        uint256 _amount,
        uint32 _dstEid,
        ComposeMsg.MessageType _messageType,
        bool _payInLzToken,
        bytes calldata _extraOptions
    ) external view validDestination(_dstEid) returns (MessagingFee memory msgFee) {
        address crossChainManager = crossChainManagers[_dstEid];

        // Encode the compose message based on message type
        bytes memory composeMsg;
        if (_messageType == ComposeMsg.MessageType.CROSS_CHAIN_SEND) {
            composeMsg = ComposeMsg.encodeCrossChainSend(_to);
        } else if (_messageType == ComposeMsg.MessageType.BURNT) {
            composeMsg = ComposeMsg.encodeBurnt(_to, _amount);
        } else {
            revert("Invalid message type");
        }

        // Build send parameters
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: _addressToBytes32(crossChainManager), // Send to cross-chain manager
            amountLD: _amount,
            minAmountLD: _amount, // No slippage for this example
            extraOptions: _extraOptions,
            composeMsg: composeMsg,
            oftCmd: "0x" // No OFT command
        });

        // Get quote from OFT core
        return this.quoteSend(sendParam, _payInLzToken);
    }

    /**
     * @notice Internal function to send tokens cross-chain with compose message
     * @param _to The recipient address
     * @param _amount The amount to send
     * @param _dstEid The destination endpoint ID
     * @param _messageType The type of compose message (CROSS_CHAIN_SEND or BURNT)
     * @param _payInLzToken Whether to pay in LZ tokens
     * @param _extraOptions Additional LayerZero options
     */
    function _sendComposed(
        address _to, 
        uint256 _amount, 
        uint32 _dstEid, 
        ComposeMsg.MessageType _messageType,
        bool _payInLzToken, 
        bytes calldata _extraOptions
    ) internal validDestination(_dstEid) {
        address crossChainManager = crossChainManagers[_dstEid];

        // Encode the compose message based on message type
        bytes memory composeMsg;
        if (_messageType == ComposeMsg.MessageType.CROSS_CHAIN_SEND) {
            composeMsg = ComposeMsg.encodeCrossChainSend(_to);
        } else if (_messageType == ComposeMsg.MessageType.BURNT) {
            composeMsg = ComposeMsg.encodeBurnt(_to, _amount);
        } else {
            revert("Invalid message type");
        }

        // Build send parameters
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: _addressToBytes32(crossChainManager), // Send to cross-chain manager
            amountLD: _amount,
            minAmountLD: _amount, // No slippage for this example
            extraOptions: _extraOptions,
            composeMsg: composeMsg,
            oftCmd: "0x" // No OFT command
        });

        // Quote the operation first
        MessagingFee memory msgFee = this.quoteSend(sendParam, _payInLzToken);

        // Execute the cross-chain send using the public interface
        uint256 feeValue = _payInLzToken ? 0 : msgFee.nativeFee;
        this.send{value: feeValue}(sendParam, msgFee, msg.sender);

        // Emit event
        emit CrossChainSendInitiated(_to, _amount, _dstEid);
    }

    /**
     * @notice Convert address to bytes32
     * @param _addr The address to convert
     * @return The bytes32 representation
     */
    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
