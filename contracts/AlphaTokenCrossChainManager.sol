// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IOAppComposer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ComposeMsg } from "./libraries/ComposeMsg.sol";

/**
 * @title AlphaTokenCrossChainManager
 * @notice Upgradeable contract that handles cross-chain operations with non-upgradeable OFT tokens
 * @dev Uses UUPS proxy pattern. Works with standard (non-upgradeable) AlphaOFT contracts.
 */
contract AlphaTokenCrossChainManager is 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    IOAppComposer 
{
    using SafeERC20 for IERC20;

    /// @notice LayerZero endpoint address
    address public endpoint;

    /// @notice Trusted OFT that can send composed messages (non-upgradeable AlphaOFT)
    address public trustedOFT;

    /// @notice Total amount processed by this contract
    uint256 public totalProcessed;

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice Events
    event EndpointUpdated(address indexed oldEndpoint, address indexed newEndpoint);
    event TrustedOFTUpdated(address indexed oldTrustedOFT, address indexed newTrustedOFT);
    event TokensProcessed(address indexed recipient, uint256 amount, ComposeMsg.MessageType messageType);
    event PausedStateChanged(bool paused);

    /// @notice Errors
    error UnauthorizedSender();
    error UntrustedOApp();
    error UnsupportedMessageType();
    error ContractPaused();
    error ZeroAddress();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the upgradeable contract
     * @param _endpoint LayerZero endpoint address
     * @param _trustedOFT Trusted non-upgradeable OFT contract address
     * @param _owner Owner of this upgradeable contract
     */
    function initialize(
        address _endpoint,
        address _trustedOFT,
        address _owner
    ) public initializer {
        if (_endpoint == address(0) || _trustedOFT == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        endpoint = _endpoint;
        trustedOFT = _trustedOFT;
        paused = false;
        totalProcessed = 0;
    }

    /**
     * @notice Handles composed messages from the non-upgradeable OFT
     * @param _oApp Address of the originating OApp (must be trusted OFT)
     * @param _guid Unique identifier for this message
     * @param _message Encoded message containing compose data
     */
    function lzCompose(
        address _oApp,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable override {
        // Check if contract is paused
        if (paused) {
            revert ContractPaused();
        }

        // Security: Verify the message source
        if (msg.sender != endpoint) {
            revert UnauthorizedSender();
        }
        if (_oApp != trustedOFT) {
            revert UntrustedOApp();
        }

        // Decode the full composed message context
        uint64 nonce = OFTComposeMsgCodec.nonce(_message);
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);

        // Get original sender (who initiated the OFT transfer)
        bytes32 composeFromBytes = OFTComposeMsgCodec.composeFrom(_message);
        address originalSender = OFTComposeMsgCodec.bytes32ToAddress(composeFromBytes);

        // Decode your custom compose message using the ComposeMsg library
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        ComposeMsg.ComposeData memory composeData = ComposeMsg.decode(composeMsg);

        // Handle different message types
        if (composeData.messageType == ComposeMsg.MessageType.CROSS_CHAIN_SEND) {
            // Transfer tokens held by this contract to the recipient
            IERC20(trustedOFT).safeTransfer(composeData.recipient, amountLD);
        } else if (composeData.messageType == ComposeMsg.MessageType.BURNT) {
            // For BURNT messages, extract the burnt amount from additional data
            uint256 burntAmount = abi.decode(composeData.additionalData, (uint256));
            
            // Transfer tokens held by this contract to the recipient
            // Note: amountLD might be different from burntAmount depending on your logic
            IERC20(trustedOFT).safeTransfer(composeData.recipient, amountLD);
            
            // You can add additional logic here based on the burnt amount
            // For example, logging or adjusting the transfer amount
        } else {
            revert UnsupportedMessageType();
        }

        // Update tracking
        totalProcessed += amountLD;

        // Emit event
        emit TokensProcessed(composeData.recipient, amountLD, composeData.messageType);
    }

    /**
     * @notice Update the LayerZero endpoint address (only owner)
     * @param _newEndpoint New endpoint address
     */
    function updateEndpoint(address _newEndpoint) external onlyOwner {
        if (_newEndpoint == address(0)) {
            revert ZeroAddress();
        }
        
        address oldEndpoint = endpoint;
        endpoint = _newEndpoint;
        
        emit EndpointUpdated(oldEndpoint, _newEndpoint);
    }

    /**
     * @notice Update the trusted OFT address (only owner)
     * @param _newTrustedOFT New trusted non-upgradeable OFT address
     */
    function updateTrustedOFT(address _newTrustedOFT) external onlyOwner {
        if (_newTrustedOFT == address(0)) {
            revert ZeroAddress();
        }
        
        address oldTrustedOFT = trustedOFT;
        trustedOFT = _newTrustedOFT;
        
        emit TrustedOFTUpdated(oldTrustedOFT, _newTrustedOFT);
    }

    /**
     * @notice Pause or unpause the contract (only owner)
     * @param _paused New paused state
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /**
     * @notice Emergency function to withdraw any stuck tokens (only owner)
     * @param _token Token address to withdraw
     * @param _to Recipient address
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        if (_to == address(0)) {
            revert ZeroAddress();
        }
        
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /**
     * @notice Required by UUPS pattern - only owner can authorize upgrades
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Get the implementation version
     * @return Version string
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}