// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Errors
 * @notice Library containing all custom errors used across the Micro-DCA Vault system
 * @dev Centralized error definitions for gas optimization and maintainability
 */
library Errors {
    /// @notice Thrown when caller is not the authorized keeper
    error NotKeeper();
    
    /// @notice Thrown when trying to execute cycle before interval has elapsed
    error IntervalNotElapsed();
    
    /// @notice Thrown when swap would exceed maximum allowed slippage
    error MaxSlippageExceeded();
    
    /// @notice Thrown when requested amount exceeds per-cycle cap
    error CapExceeded();
    
    /// @notice Thrown when contract is paused
    error Paused();
    
    /// @notice Thrown when a zero address is provided where it's not allowed
    error ZeroAddress();
    
    /// @notice Thrown when invalid parameters are provided
    error InvalidParams();
    
    /// @notice Thrown when caller is not authorized relayer
    error NotRelayer();
    
    /// @notice Thrown when meta-transaction has expired
    error MetaTxExpired();
}
