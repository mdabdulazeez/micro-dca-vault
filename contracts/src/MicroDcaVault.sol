// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title MicroDcaVault
 * @notice ERC-4626 compliant vault that performs micro dollar-cost averaging (DCA)
 * @dev Periodically swaps small amounts of quote tokens for base tokens via DEX router
 */
contract MicroDcaVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice DEX router for token swaps
    IRouter public immutable router;
    
    /// @notice Token being purchased (target asset)
    IERC20 public immutable baseToken;
    
    /// @notice Token being sold (ERC-4626 asset, what users deposit)
    IERC20 public immutable quoteToken;

    /// @notice Minimum time between DCA cycles in seconds
    uint256 public intervalSeconds;
    
    /// @notice Maximum allowed slippage in basis points (e.g., 50 = 0.50%)
    uint256 public maxSlippageBps;
    
    /// @notice Maximum quote tokens to swap per cycle
    uint256 public perCycleQuoteCap;
    
    /// @notice Protocol fee in basis points charged on base token output
    uint256 public feeBps;
    
    /// @notice Authorized keeper address (zero address = anyone can call)
    address public keeper;
    
    /// @notice Emergency pause flag
    bool public paused;

    /// @notice Timestamp of last cycle execution
    uint256 public lastExec;
    
    /// @notice Total quote tokens filled across all cycles
    uint256 public totalFilledQuote;
    
    /// @notice Total base tokens acquired across all cycles
    uint256 public totalFilledBase;

    /**
     * @notice Emitted when a DCA cycle is executed
     * @param timestamp Block timestamp of execution
     * @param quoteIn Amount of quote tokens swapped
     * @param baseOut Amount of base tokens received (after fees)
     */
    event Fill(uint256 indexed timestamp, uint256 quoteIn, uint256 baseOut);

    /**
     * @notice Emitted when vault configuration is updated
     * @param intervalSeconds New interval between cycles
     * @param maxSlippageBps New maximum slippage tolerance
     * @param perCycleQuoteCap New per-cycle swap limit
     * @param feeBps New protocol fee rate
     * @param keeper New keeper address
     * @param paused New pause state
     */
    event ConfigUpdated(
        uint256 intervalSeconds,
        uint256 maxSlippageBps,
        uint256 perCycleQuoteCap,
        uint256 feeBps,
        address keeper,
        bool paused
    );

    /**
     * @notice Deploy a new MicroDcaVault
     * @param _router DEX router address for swaps
     * @param _base Base token address (what we buy)
     * @param _quote Quote token address (ERC-4626 asset, what users deposit)
     * @param _intervalSeconds Minimum seconds between cycles
     * @param _maxSlippageBps Maximum slippage in basis points
     * @param _perCycleQuoteCap Maximum quote tokens per cycle
     * @param _feeBps Protocol fee in basis points
     * @param _owner Owner address for access control
     */
    constructor(
        address _router,
        address _base,
        address _quote,
        uint256 _intervalSeconds,
        uint256 _maxSlippageBps,
        uint256 _perCycleQuoteCap,
        uint256 _feeBps,
        address _owner
    )
        ERC20(
            string(abi.encodePacked("MicroDCA-", ERC20(_base).symbol())),
            string(abi.encodePacked("v", ERC20(_base).symbol()))
        )
        ERC4626(IERC20(_quote))
        Ownable(_owner)
    {
        if (_router == address(0) || _base == address(0) || _quote == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        router = IRouter(_router);
        baseToken = IERC20(_base);
        quoteToken = IERC20(_quote);

        intervalSeconds = _intervalSeconds;
        maxSlippageBps = _maxSlippageBps;
        perCycleQuoteCap = _perCycleQuoteCap;
        feeBps = _feeBps;

        lastExec = block.timestamp;
    }

    /**
     * @notice Modifier to check if vault is not paused
     */
    modifier notPaused() {
        if (paused) revert Errors.Paused();
        _;
    }

    /**
     * @notice Update vault configuration (owner only)
     * @param _intervalSeconds New interval between cycles
     * @param _maxSlippageBps New maximum slippage tolerance
     * @param _perCycleQuoteCap New per-cycle swap limit
     * @param _feeBps New protocol fee rate
     * @param _keeper New keeper address (zero = anyone can call)
     * @param _paused New pause state
     */
    function setConfig(
        uint256 _intervalSeconds,
        uint256 _maxSlippageBps,
        uint256 _perCycleQuoteCap,
        uint256 _feeBps,
        address _keeper,
        bool _paused
    ) external onlyOwner {
        intervalSeconds = _intervalSeconds;
        maxSlippageBps = _maxSlippageBps;
        perCycleQuoteCap = _perCycleQuoteCap;
        feeBps = _feeBps;
        keeper = _keeper;
        paused = _paused;
        
        emit ConfigUpdated(_intervalSeconds, _maxSlippageBps, _perCycleQuoteCap, _feeBps, _keeper, _paused);
    }

    /**
     * @notice Get the next allowed execution time
     * @return Next timestamp when executeCycle can be called
     */
    function nextExecTime() external view returns (uint256) {
        return lastExec + intervalSeconds;
    }

    /**
     * @notice Get current vault configuration
     * @return intervalSeconds, maxSlippageBps, perCycleQuoteCap, feeBps, keeper, paused
     */
    function getConfig() external view returns (
        uint256, uint256, uint256, uint256, address, bool
    ) {
        return (intervalSeconds, maxSlippageBps, perCycleQuoteCap, feeBps, keeper, paused);
    }

    /**
     * @notice Preview the expected output for a given quote amount (passthrough for MVP)
     * @param quoteAmount Amount of quote tokens to swap
     * @return Expected minimum output (relies on external pricing)
     */
    function previewCycleOut(uint256 quoteAmount) external pure returns (uint256) {
        // MVP: Simple passthrough - real implementation would use price oracle
        return quoteAmount; // Placeholder for 1:1 rate
    }

    /**
     * @notice Execute a DCA cycle by swapping quote tokens for base tokens
     * @param quoteAmount Amount of quote tokens to swap
     * @param minOut Minimum base tokens expected (slippage protection)
     * @param beneficiary Intended beneficiary (unused in MVP - all assets remain in vault)
     * @return baseOut Amount of base tokens received after fees
     */
    function executeCycle(
        uint256 quoteAmount,
        uint256 minOut,
        address beneficiary
    ) external notPaused nonReentrant returns (uint256 baseOut) {
        // Access control: either anyone (keeper == 0) or specific keeper
        if (keeper != address(0) && msg.sender != keeper) {
            revert Errors.NotKeeper();
        }
        
        // Time-based execution control
        if (block.timestamp < lastExec + intervalSeconds) {
            revert Errors.IntervalNotElapsed();
        }
        
        // Cap enforcement
        if (quoteAmount > perCycleQuoteCap) {
            revert Errors.CapExceeded();
        }

        // Balance check and soft bounding
        uint256 avail = IERC20(asset()).balanceOf(address(this));
        if (quoteAmount > avail) {
            quoteAmount = avail; // Soft bound to available balance
        }
        require(quoteAmount > 0, "NoQuote");

        // Build swap path: quote -> base
        address[] memory path = new address[](2);
        path[0] = address(quoteToken);
        path[1] = address(baseToken);

        // Approve router for swap
        IERC20(asset()).forceApprove(address(router), 0);
        IERC20(asset()).forceApprove(address(router), quoteAmount);

        // Execute swap with deadline
        uint256 deadline = block.timestamp + 300; // 5 minute deadline
        uint[] memory amounts = router.swapExactTokensForTokens(
            quoteAmount,
            minOut,
            path,
            address(this), // Receive tokens to vault
            deadline
        );

        baseOut = amounts[amounts.length - 1]; // Last element is output amount

        // Slippage check (MVP: rely on minOut from UI)
        require(baseOut >= minOut, "Slippage");

        // Protocol fee deduction on base token output
        uint256 fee = (baseOut * feeBps) / 10_000;
        if (fee > 0) {
            baseToken.safeTransfer(owner(), fee);
            baseOut -= fee;
        }

        // Update state
        lastExec = block.timestamp;
        totalFilledQuote += quoteAmount;
        totalFilledBase += baseOut;

        emit Fill(block.timestamp, quoteAmount, baseOut);

        // beneficiary parameter unused in MVP (all assets remain in vault for ERC-4626 accounting)
        beneficiary; // Silence unused parameter warning
    }

    /**
     * @notice Get total value of all assets held by the vault
     * @return Total assets in quote token terms (for ERC-4626 compatibility)
     * @dev For MVP, this includes both quote and base tokens at current balances
     */
    function totalAssets() public view override returns (uint256) {
        // MVP: Return quote token balance + base token balance (1:1 assumed for simplicity)
        // Real implementation would need price oracle to convert base to quote value
        uint256 quoteBalance = IERC20(asset()).balanceOf(address(this));
        uint256 baseBalance = baseToken.balanceOf(address(this));
        
        // Simplified 1:1 conversion for demo - replace with oracle price in production
        return quoteBalance + baseBalance;
    }
}
