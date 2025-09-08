// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IRouter
 * @notice Interface for DEX router compatible with UniswapV2-like functionality
 * @dev Minimal interface for token swapping functionality needed by Micro-DCA Vault
 */
interface IRouter {
    /**
     * @notice Swaps an exact amount of input tokens for as many output tokens as possible
     * @param amountIn The amount of input tokens to send
     * @param amountOutMin The minimum amount of output tokens that must be received
     * @param path An array of token addresses representing the swap path
     * @param to Recipient of the output tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amounts The input token amount and all subsequent output token amounts
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}
