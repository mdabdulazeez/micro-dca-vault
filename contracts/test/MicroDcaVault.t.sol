// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MicroDcaVault} from "../src/MicroDcaVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is Test {
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
    uint256 public rate = 1e18; // 1:1 by default
    uint256 public slippageSimulation = 0; // 0 = no slippage
    
    function setRate(uint256 _rate) external {
        rate = _rate;
    }
    
    function setSlippage(uint256 _slippageBps) external {
        slippageSimulation = _slippageBps;
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
        
        // Calculate output with rate and simulate slippage
        uint256 amountOut = (amountIn * rate) / 1e18;
        uint256 slippageAmount = (amountOut * slippageSimulation) / 10000;
        amountOut -= slippageAmount;
        
        require(amountOut >= amountOutMin, "INSUFFICIENT_OUTPUT");
        
        // Transfer tokens
        MockERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(path[1]).transfer(to, amountOut);
        
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }
}

contract MicroDcaVaultTest is Test {
    MicroDcaVault public vault;
    VaultFactory public factory;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    MockRouter public router;
    
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public keeper = makeAddr("keeper");
    
    uint256 constant INTERVAL = 60; // 1 minute
    uint256 constant MAX_SLIPPAGE_BPS = 50; // 0.5%
    uint256 constant PER_CYCLE_CAP = 100e18; // 100 tokens
    uint256 constant FEE_BPS = 10; // 0.1%
    
    event Fill(uint256 indexed timestamp, uint256 quoteIn, uint256 baseOut);

    function setUp() public {
        // Deploy mock tokens
        baseToken = new MockERC20("Base Token", "BASE", 18);
        quoteToken = new MockERC20("Quote Token", "QUOTE", 18);
        router = new MockRouter();
        
        // Deploy factory and vault
        factory = new VaultFactory(address(router));
        
        vm.prank(owner);
        address vaultAddr = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            address(0) // No keeper restriction
        );
        
        vault = MicroDcaVault(vaultAddr);
        
        // Mint tokens for testing
        quoteToken.mint(user1, 10000e18);
        quoteToken.mint(user2, 10000e18);
        baseToken.mint(address(router), 10000e18);
        
        // Setup approvals
        vm.prank(user1);
        quoteToken.approve(address(vault), type(uint256).max);
        
        vm.prank(user2);
        quoteToken.approve(address(vault), type(uint256).max);
    }

    function testConstructor() public {
        assertEq(address(vault.router()), address(router));
        assertEq(address(vault.baseToken()), address(baseToken));
        assertEq(address(vault.quoteToken()), address(quoteToken));
        assertEq(vault.owner(), owner);
        assertEq(vault.intervalSeconds(), INTERVAL);
        assertEq(vault.maxSlippageBps(), MAX_SLIPPAGE_BPS);
        assertEq(vault.perCycleQuoteCap(), PER_CYCLE_CAP);
        assertEq(vault.feeBps(), FEE_BPS);
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new MicroDcaVault(
            address(0), // zero router
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            owner
        );
    }

    function testDeposit() public {
        uint256 depositAmount = 1000e18;
        
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        assertEq(shares, depositAmount); // 1:1 for first deposit
        assertEq(vault.balanceOf(user1), shares);
        assertEq(quoteToken.balanceOf(address(vault)), depositAmount);
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000e18;
        
        // Deposit first
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);
        
        // Withdraw half
        uint256 withdrawAmount = 500e18;
        vm.prank(user1);
        uint256 assets = vault.redeem(withdrawAmount, user1, user1);
        
        assertEq(assets, withdrawAmount); // 1:1 redemption
        assertEq(vault.balanceOf(user1), shares - withdrawAmount);
    }

    function testExecuteCycle() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmount = 50e18;
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Execute cycle
        uint256 minOut = swapAmount; // 1:1 rate expected
        uint256 baseOut = vault.executeCycle(swapAmount, minOut, user1);
        
        // Check results
        assertEq(baseOut, swapAmount - (swapAmount * FEE_BPS / 10000)); // Minus fee
        assertEq(vault.totalFilledQuote(), swapAmount);
        assertEq(vault.lastExec(), block.timestamp);
    }

    function testExecuteCycleIntervalRestriction() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmount = 50e18;
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // First execution should work
        vault.executeCycle(swapAmount, swapAmount, user1);
        
        // Second execution immediately should fail
        vm.expectRevert(Errors.IntervalNotElapsed.selector);
        vault.executeCycle(swapAmount, swapAmount, user1);
        
        // After interval, should work again
        vm.warp(block.timestamp + INTERVAL + 1);
        vault.executeCycle(swapAmount, swapAmount, user1);
    }

    function testExecuteCycleCapRestriction() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmount = PER_CYCLE_CAP + 1;
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Should fail due to cap
        vm.expectRevert(Errors.CapExceeded.selector);
        vault.executeCycle(swapAmount, swapAmount, user1);
    }

    function testExecuteCycleKeeperRestriction() public {
        // Create vault with keeper restriction
        vm.prank(owner);
        address restrictedVaultAddr = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );
        
        MicroDcaVault restrictedVault = MicroDcaVault(restrictedVaultAddr);
        
        // Deposit funds
        vm.prank(user1);
        quoteToken.approve(address(restrictedVault), type(uint256).max);
        vm.prank(user1);
        restrictedVault.deposit(1000e18, user1);
        
        // Non-keeper should fail
        vm.prank(user1);
        vm.expectRevert(Errors.NotKeeper.selector);
        restrictedVault.executeCycle(50e18, 50e18, user1);
        
        // Keeper should succeed
        vm.prank(keeper);
        restrictedVault.executeCycle(50e18, 50e18, user1);
    }

    function testExecuteCyclePaused() public {
        uint256 depositAmount = 1000e18;
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Pause vault
        vm.prank(owner);
        vault.setConfig(INTERVAL, MAX_SLIPPAGE_BPS, PER_CYCLE_CAP, FEE_BPS, address(0), true);
        
        // Should fail when paused
        vm.expectRevert(Errors.Paused.selector);
        vault.executeCycle(50e18, 50e18, user1);
    }

    function testExecuteCycleSlippageProtection() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmount = 50e18;
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Set high slippage on router
        router.setSlippage(1000); // 10% slippage
        
        uint256 minOut = swapAmount; // Expect no slippage
        vm.expectRevert("Slippage");
        vault.executeCycle(swapAmount, minOut, user1);
        
        // With appropriate minOut, should work
        uint256 appropriateMinOut = swapAmount * 90 / 100; // Accept 10% slippage
        vault.executeCycle(swapAmount, appropriateMinOut, user1);
    }

    function testSetConfig() public {
        uint256 newInterval = 120;
        uint256 newSlippage = 100;
        uint256 newCap = 200e18;
        uint256 newFee = 20;
        address newKeeper = makeAddr("newKeeper");
        
        vm.prank(owner);
        vault.setConfig(newInterval, newSlippage, newCap, newFee, newKeeper, false);
        
        (uint256 interval, uint256 slippage, uint256 cap, uint256 fee, address keeperAddr, bool paused) = vault.getConfig();
        
        assertEq(interval, newInterval);
        assertEq(slippage, newSlippage);
        assertEq(cap, newCap);
        assertEq(fee, newFee);
        assertEq(keeperAddr, newKeeper);
        assertEq(paused, false);
    }

    function testSetConfigOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.setConfig(120, 100, 200e18, 20, address(0), false);
    }

    function testNextExecTime() public {
        uint256 currentTime = block.timestamp;
        assertEq(vault.nextExecTime(), currentTime + INTERVAL);
        
        // After execution, should update
        vm.prank(user1);
        vault.deposit(1000e18, user1);
        
        vm.warp(currentTime + INTERVAL + 1);
        vault.executeCycle(50e18, 50e18, user1);
        
        assertEq(vault.nextExecTime(), currentTime + INTERVAL + 1 + INTERVAL);
    }

    function testFillEvent() public {
        uint256 depositAmount = 1000e18;
        uint256 swapAmount = 50e18;
        
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        vm.expectEmit(true, true, true, true);
        emit Fill(block.timestamp, swapAmount, swapAmount - (swapAmount * FEE_BPS / 10000));
        
        vault.executeCycle(swapAmount, swapAmount, user1);
    }

    function testTotalAssets() public {
        uint256 depositAmount = 1000e18;
        
        // Initially should be 0
        assertEq(vault.totalAssets(), 0);
        
        // After deposit
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        assertEq(vault.totalAssets(), depositAmount);
        
        // After swap (simplified 1:1 conversion)
        uint256 swapAmount = 100e18;
        vault.executeCycle(swapAmount, swapAmount, user1);
        
        // Should include both quote and base token balances
        uint256 expectedTotal = (depositAmount - swapAmount) + (swapAmount - (swapAmount * FEE_BPS / 10000));
        assertEq(vault.totalAssets(), expectedTotal);
    }

    function testFuzzDeposit(uint256 amount) public {
        // Bound the amount to reasonable values
        amount = bound(amount, 1e6, 1e25); // 0.000001 to 10M tokens
        
        // Mint tokens to user
        quoteToken.mint(user1, amount);
        
        vm.prank(user1);
        quoteToken.approve(address(vault), amount);
        
        vm.prank(user1);
        uint256 shares = vault.deposit(amount, user1);
        
        assertEq(shares, amount); // Should be 1:1 for first deposit
        assertEq(vault.balanceOf(user1), shares);
    }

    function testFuzzExecuteCycle(uint256 depositAmount, uint256 swapAmount) public {
        depositAmount = bound(depositAmount, 100e18, 10000e18);
        swapAmount = bound(swapAmount, 1e18, PER_CYCLE_CAP);
        
        // Ensure we have enough to swap
        vm.assume(swapAmount <= depositAmount);
        
        // Deposit funds
        vm.prank(user1);
        vault.deposit(depositAmount, user1);
        
        // Execute cycle
        uint256 expectedOut = swapAmount - (swapAmount * FEE_BPS / 10000);
        uint256 actualOut = vault.executeCycle(swapAmount, expectedOut, user1);
        
        assertEq(actualOut, expectedOut);
        assertEq(vault.totalFilledQuote(), swapAmount);
    }
}
