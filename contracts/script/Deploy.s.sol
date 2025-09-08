// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {Relayer} from "../src/Relayer.sol";
import {MicroDcaVault} from "../src/MicroDcaVault.sol";

/**
 * @title Deploy
 * @notice Deployment script for Micro-DCA Vault system
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract Deploy is Script {
    // Default configuration values
    uint256 constant DEFAULT_INTERVAL = 60; // 1 minute
    uint256 constant DEFAULT_MAX_SLIPPAGE_BPS = 50; // 0.5%
    uint256 constant DEFAULT_PER_CYCLE_CAP = 100e18; // 100 tokens
    uint256 constant DEFAULT_FEE_BPS = 10; // 0.1%
    uint256 constant DEFAULT_RELAYER_FEE_BPS = 25; // 0.25%

    // Deployment addresses (will be set from environment or defaults)
    address router;
    address baseToken;
    address quoteToken;

    function setUp() public {
        // Set router address from environment or use a default
        router = vm.envOr("ROUTER_ADDRESS", address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)); // Uniswap V2 Router
        
        // Set token addresses from environment (these should be set for mainnet deployments)
        baseToken = vm.envOr("BASE_TOKEN_ADDRESS", address(0x0)); // Must be set for production
        quoteToken = vm.envOr("QUOTE_TOKEN_ADDRESS", address(0x0)); // Must be set for production
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts...");
        console.log("Deployer address:", deployer);
        console.log("Router address:", router);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy VaultFactory
        VaultFactory factory = new VaultFactory(router);
        console.log("VaultFactory deployed at:", address(factory));

        // Deploy Relayer
        Relayer relayer = new Relayer(DEFAULT_RELAYER_FEE_BPS, deployer);
        console.log("Relayer deployed at:", address(relayer));

        // Deploy example vault if tokens are specified
        if (baseToken != address(0) && quoteToken != address(0)) {
            console.log("Creating example vault...");
            console.log("Base token:", baseToken);
            console.log("Quote token:", quoteToken);
            
            address exampleVault = factory.createVault(
                baseToken,
                quoteToken,
                DEFAULT_INTERVAL,
                DEFAULT_MAX_SLIPPAGE_BPS,
                DEFAULT_PER_CYCLE_CAP,
                DEFAULT_FEE_BPS,
                address(0) // No keeper restriction
            );
            
            console.log("Example vault deployed at:", exampleVault);
        } else {
            console.log("Skipping example vault deployment (no tokens specified)");
        }

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", block.chainid);
        console.log("VaultFactory:", address(factory));
        console.log("Relayer:", address(relayer));
        console.log("Router:", router);
        
        // Save addresses to file for frontend
        string memory addresses = string(abi.encodePacked(
            "NEXT_PUBLIC_VAULT_FACTORY_ADDRESS=", vm.toString(address(factory)), "\n",
            "NEXT_PUBLIC_RELAYER_ADDRESS=", vm.toString(address(relayer)), "\n",
            "NEXT_PUBLIC_ROUTER_ADDRESS=", vm.toString(router), "\n"
        ));
        
        vm.writeFile(".env.local", addresses);
        console.log("Addresses saved to .env.local");
    }
}

/**
 * @title DeployMocks
 * @notice Deploy mock tokens and router for testing
 * @dev Run with: forge script script/Deploy.s.sol:DeployMocks --rpc-url $RPC_URL --broadcast
 */
contract DeployMocks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying mock contracts for testing...");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        MockERC20 baseToken = new MockERC20("Base Token", "BASE", 18);
        MockERC20 quoteToken = new MockERC20("Quote Token", "QUOTE", 18);
        
        // Deploy mock router
        MockRouter mockRouter = new MockRouter();
        
        console.log("Base token deployed at:", address(baseToken));
        console.log("Quote token deployed at:", address(quoteToken));
        console.log("Mock router deployed at:", address(mockRouter));
        
        // Mint some tokens to deployer for testing
        baseToken.mint(deployer, 1000000e18);
        quoteToken.mint(deployer, 1000000e18);
        
        // Add liquidity to mock router
        mockRouter.addLiquidity(address(quoteToken), address(baseToken), 1e18); // 1:1 rate

        vm.stopBroadcast();

        // Save mock addresses
        string memory mockAddresses = string(abi.encodePacked(
            "BASE_TOKEN_ADDRESS=", vm.toString(address(baseToken)), "\n",
            "QUOTE_TOKEN_ADDRESS=", vm.toString(address(quoteToken)), "\n",
            "ROUTER_ADDRESS=", vm.toString(address(mockRouter)), "\n"
        ));
        
        vm.writeFile(".env.mocks", mockAddresses);
        console.log("Mock addresses saved to .env.mocks");
    }
}

// Mock contracts for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MockRouter {
    mapping(address => mapping(address => uint256)) public rates; // token0 -> token1 -> rate (1e18 = 1:1)
    
    function addLiquidity(address token0, address token1, uint256 rate) external {
        rates[token0][token1] = rate;
        rates[token1][token0] = 1e18 * 1e18 / rate; // Inverse rate
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "EXPIRED");
        require(path.length == 2, "INVALID_PATH");
        
        address tokenIn = path[0];
        address tokenOut = path[1];
        uint256 rate = rates[tokenIn][tokenOut];
        require(rate > 0, "NO_LIQUIDITY");
        
        // Simple rate calculation with 0.3% fee (like Uniswap)
        uint256 amountOut = (amountIn * rate * 997) / (1000 * 1e18);
        require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT");
        
        // Transfer tokens
        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).transfer(to, amountOut);
        
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}
