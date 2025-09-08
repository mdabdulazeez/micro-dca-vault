// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MicroDcaVault} from "./MicroDcaVault.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title VaultFactory
 * @notice Factory contract for creating and copying MicroDcaVault instances
 * @dev Enables social copying of successful vault strategies
 */
contract VaultFactory {
    /// @notice DEX router address used for all created vaults
    address public immutable router;

    /// @notice Array of all created vault addresses
    address[] public allVaults;

    /// @notice Mapping to check if an address is a valid vault from this factory
    mapping(address => bool) public isVault;

    /**
     * @notice Emitted when a new vault is created
     * @param vault Address of the created vault
     * @param base Base token address
     * @param quote Quote token address  
     * @param creator Address of the vault creator
     */
    event VaultCreated(
        address indexed vault, 
        address indexed base, 
        address indexed quote, 
        address creator
    );

    /**
     * @notice Emitted when a vault is copied
     * @param src Address of the source vault being copied
     * @param copy Address of the newly created copy
     * @param creator Address who initiated the copy
     */
    event VaultCopied(
        address indexed src, 
        address indexed copy, 
        address indexed creator
    );

    /**
     * @notice Deploy the factory with a router address
     * @param _router DEX router address for all vaults
     */
    constructor(address _router) {
        if (_router == address(0)) revert Errors.ZeroAddress();
        router = _router;
    }

    /**
     * @notice Create a new MicroDcaVault with specified parameters
     * @param base Base token address (what the vault buys)
     * @param quote Quote token address (what users deposit)
     * @param intervalSeconds Minimum seconds between DCA cycles
     * @param maxSlippageBps Maximum slippage tolerance in basis points
     * @param perCycleQuoteCap Maximum quote tokens to swap per cycle
     * @param feeBps Protocol fee in basis points
     * @param keeper Authorized keeper address (zero = anyone can execute)
     * @return vault Address of the created vault
     */
    function createVault(
        address base,
        address quote,
        uint256 intervalSeconds,
        uint256 maxSlippageBps,
        uint256 perCycleQuoteCap,
        uint256 feeBps,
        address keeper
    ) external returns (address vault) {
        // Input validation
        if (base == address(0) || quote == address(0)) {
            revert Errors.ZeroAddress();
        }
        if (base == quote) {
            revert Errors.InvalidParams();
        }
        if (intervalSeconds == 0 || maxSlippageBps > 10000 || feeBps > 10000) {
            revert Errors.InvalidParams();
        }

        // Deploy new vault with msg.sender as owner
        vault = address(new MicroDcaVault(
            router,
            base,
            quote,
            intervalSeconds,
            maxSlippageBps,
            perCycleQuoteCap,
            feeBps,
            msg.sender
        ));

        // Track the vault
        allVaults.push(vault);
        isVault[vault] = true;

        emit VaultCreated(vault, base, quote, msg.sender);
    }

    /**
     * @notice Copy an existing vault's configuration to create a new vault
     * @param src Address of the vault to copy
     * @return vault Address of the newly created copy
     * @dev The copy will have msg.sender as owner and keeper set to zero address (permissionless)
     */
    function copyVault(address src) external returns (address vault) {
        if (src == address(0)) revert Errors.ZeroAddress();
        
        // Verify the source is a valid MicroDcaVault (basic check)
        try MicroDcaVault(src).getConfig() returns (
            uint256 intervalSeconds,
            uint256 maxSlippageBps,
            uint256 perCycleQuoteCap,
            uint256 feeBps,
            address, // ignore keeper from source
            bool     // ignore paused state from source
        ) {
            // Get token addresses from source vault
            address base = address(MicroDcaVault(src).baseToken());
            address quote = address(MicroDcaVault(src).quoteToken());

            // Deploy copy with same parameters but msg.sender as owner and no keeper restriction
            vault = address(new MicroDcaVault(
                router,
                base,
                quote,
                intervalSeconds,
                maxSlippageBps,
                perCycleQuoteCap,
                feeBps,
                msg.sender // New owner
            ));

            // Track the vault
            allVaults.push(vault);
            isVault[vault] = true;

            emit VaultCopied(src, vault, msg.sender);
        } catch {
            revert Errors.InvalidParams();
        }
    }

    /**
     * @notice Get all vault addresses created by this factory
     * @return Array of all vault addresses
     */
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }

    /**
     * @notice Get the total number of vaults created
     * @return Total count of vaults
     */
    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    /**
     * @notice Get vault address at specific index
     * @param index Index in the allVaults array
     * @return Vault address at the given index
     */
    function getVault(uint256 index) external view returns (address) {
        require(index < allVaults.length, "Index out of bounds");
        return allVaults[index];
    }

    /**
     * @notice Get a page of vaults for UI pagination
     * @param offset Starting index
     * @param limit Maximum number of vaults to return
     * @return vaults Array of vault addresses
     * @return total Total number of vaults
     */
    function getVaultsPaginated(uint256 offset, uint256 limit) 
        external 
        view 
        returns (address[] memory vaults, uint256 total) 
    {
        total = allVaults.length;
        
        if (offset >= total) {
            return (new address[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 length = end - offset;
        vaults = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            vaults[i] = allVaults[offset + i];
        }
    }
}
