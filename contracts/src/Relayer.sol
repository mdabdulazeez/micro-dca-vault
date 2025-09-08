// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MicroDcaVault} from "./MicroDcaVault.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title Relayer
 * @notice Meta-transaction relayer for gasless execution of DCA cycles
 * @dev Uses EIP-712 signatures to enable gasless user experience
 */
contract Relayer is EIP712, Ownable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice Fee charged by relayer in basis points
    uint256 public relayerFeeBps;

    /// @notice Maximum fee that can be set (10% = 1000 bps)
    uint256 public constant MAX_RELAYER_FEE_BPS = 1000;

    /// @notice Nonces for each user to prevent replay attacks
    mapping(address => uint256) public nonces;

    /// @notice EIP-712 type hash for ExecuteCycle struct
    bytes32 public constant EXECUTE_CYCLE_TYPEHASH = keccak256(
        "ExecuteCycle(address vault,uint256 quoteAmount,uint256 minOut,address beneficiary,uint256 deadline,uint256 nonce)"
    );

    /**
     * @notice Data structure for meta-transaction execution
     * @param vault Address of the MicroDcaVault
     * @param quoteAmount Amount of quote tokens to swap
     * @param minOut Minimum base tokens expected
     * @param beneficiary Intended beneficiary address
     * @param deadline Expiration timestamp
     * @param nonce User's current nonce
     */
    struct ExecuteCycle {
        address vault;
        uint256 quoteAmount;
        uint256 minOut;
        address beneficiary;
        uint256 deadline;
        uint256 nonce;
    }

    /**
     * @notice Emitted when a meta-transaction is executed
     * @param user Address of the user who signed the transaction
     * @param vault Address of the vault
     * @param quoteAmount Amount swapped
     * @param baseOut Amount received
     * @param relayerFee Fee paid to relayer
     */
    event MetaTxExecuted(
        address indexed user,
        address indexed vault,
        uint256 quoteAmount,
        uint256 baseOut,
        uint256 relayerFee
    );

    /**
     * @notice Emitted when relayer fee is updated
     * @param oldFee Previous fee in basis points
     * @param newFee New fee in basis points
     */
    event RelayerFeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * @notice Deploy the relayer contract
     * @param _initialFee Initial relayer fee in basis points
     * @param _owner Owner address for access control
     */
    constructor(uint256 _initialFee, address _owner) 
        EIP712("MicroDcaRelayer", "1") 
        Ownable(_owner)
    {
        if (_initialFee > MAX_RELAYER_FEE_BPS) {
            revert Errors.InvalidParams();
        }
        relayerFeeBps = _initialFee;
    }

    /**
     * @notice Set the relayer fee (owner only)
     * @param _feeBps New fee in basis points (max 10%)
     */
    function setRelayerFee(uint256 _feeBps) external onlyOwner {
        if (_feeBps > MAX_RELAYER_FEE_BPS) {
            revert Errors.InvalidParams();
        }
        
        uint256 oldFee = relayerFeeBps;
        relayerFeeBps = _feeBps;
        
        emit RelayerFeeUpdated(oldFee, _feeBps);
    }

    /**
     * @notice Execute a DCA cycle via meta-transaction
     * @param executeCycle The execution parameters
     * @param signature EIP-712 signature from the user
     * @return baseOut Amount of base tokens received after fees
     */
    function executeMetaCycle(
        ExecuteCycle calldata executeCycle,
        bytes calldata signature
    ) external returns (uint256 baseOut) {
        // Verify deadline
        if (block.timestamp > executeCycle.deadline) {
            revert Errors.MetaTxExpired();
        }

        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            EXECUTE_CYCLE_TYPEHASH,
            executeCycle.vault,
            executeCycle.quoteAmount,
            executeCycle.minOut,
            executeCycle.beneficiary,
            executeCycle.deadline,
            executeCycle.nonce
        ));

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        // Verify nonce
        if (executeCycle.nonce != nonces[signer]) {
            revert Errors.InvalidParams();
        }

        // Increment nonce to prevent replay
        nonces[signer]++;

        // Execute the cycle on behalf of the signer
        MicroDcaVault vault = MicroDcaVault(executeCycle.vault);
        
        try vault.executeCycle(
            executeCycle.quoteAmount,
            executeCycle.minOut,
            executeCycle.beneficiary
        ) returns (uint256 baseReceived) {
            baseOut = baseReceived;

            // Calculate relayer fee on the base token output
            uint256 relayerFee = (baseOut * relayerFeeBps) / 10_000;
            
            if (relayerFee > 0) {
                // Transfer relayer fee from vault to relayer (msg.sender)
                IERC20 baseToken = vault.baseToken();
                baseToken.safeTransferFrom(address(vault), msg.sender, relayerFee);
                
                // Adjust baseOut to account for relayer fee
                baseOut -= relayerFee;
            }

            emit MetaTxExecuted(
                signer,
                executeCycle.vault,
                executeCycle.quoteAmount,
                baseOut,
                relayerFee
            );

        } catch (bytes memory reason) {
            // Re-throw the original error
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }

    /**
     * @notice Get the current nonce for a user
     * @param user User address
     * @return Current nonce value
     */
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    /**
     * @notice Get the domain separator for EIP-712
     * @return The domain separator hash
     */
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Generate the typed data hash for a given ExecuteCycle struct
     * @param executeCycle The execution parameters
     * @return The typed data hash ready for signing
     */
    function getTypedDataHash(ExecuteCycle calldata executeCycle) external view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            EXECUTE_CYCLE_TYPEHASH,
            executeCycle.vault,
            executeCycle.quoteAmount,
            executeCycle.minOut,
            executeCycle.beneficiary,
            executeCycle.deadline,
            executeCycle.nonce
        ));

        return _hashTypedDataV4(structHash);
    }

    /**
     * @notice Verify a signature for an ExecuteCycle struct
     * @param executeCycle The execution parameters
     * @param signature The signature to verify
     * @return signer The address that signed the message
     * @return isValid Whether the signature is valid and not expired
     */
    function verifySignature(
        ExecuteCycle calldata executeCycle,
        bytes calldata signature
    ) external view returns (address signer, bool isValid) {
        // Check if expired
        if (block.timestamp > executeCycle.deadline) {
            return (address(0), false);
        }

        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            EXECUTE_CYCLE_TYPEHASH,
            executeCycle.vault,
            executeCycle.quoteAmount,
            executeCycle.minOut,
            executeCycle.beneficiary,
            executeCycle.deadline,
            executeCycle.nonce
        ));

        bytes32 hash = _hashTypedDataV4(structHash);
        signer = hash.recover(signature);

        // Check nonce
        isValid = (executeCycle.nonce == nonces[signer]) && (signer != address(0));
    }
}
