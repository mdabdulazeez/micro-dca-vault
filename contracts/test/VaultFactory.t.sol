// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {MicroDcaVault} from "../src/MicroDcaVault.sol";
import {Errors} from "../src/libraries/Errors.sol";

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

contract VaultFactoryTest is Test {
    VaultFactory public factory;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;
    MockERC20 public baseToken2;
    MockERC20 public quoteToken2;
    address public router = makeAddr("router");
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public keeper = makeAddr("keeper");
    
    uint256 constant INTERVAL = 60;
    uint256 constant MAX_SLIPPAGE_BPS = 50;
    uint256 constant PER_CYCLE_CAP = 100e18;
    uint256 constant FEE_BPS = 10;

    event VaultCreated(address indexed vault, address indexed base, address indexed quote, address creator);
    event VaultCopied(address indexed src, address indexed copy, address indexed creator);

    function setUp() public {
        factory = new VaultFactory(router);
        
        baseToken = new MockERC20("Base Token", "BASE", 18);
        quoteToken = new MockERC20("Quote Token", "QUOTE", 18);
        baseToken2 = new MockERC20("Base Token 2", "BASE2", 18);
        quoteToken2 = new MockERC20("Quote Token 2", "QUOTE2", 18);
    }

    function testConstructor() public {
        assertEq(factory.router(), router);
        assertEq(factory.getVaultCount(), 0);
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new VaultFactory(address(0));
    }

    function testCreateVault() public {
        vm.prank(user1);
        address vault = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        // Check vault was created correctly
        MicroDcaVault vaultContract = MicroDcaVault(vault);
        assertEq(address(vaultContract.baseToken()), address(baseToken));
        assertEq(address(vaultContract.quoteToken()), address(quoteToken));
        assertEq(vaultContract.owner(), user1);
        assertEq(vaultContract.intervalSeconds(), INTERVAL);
        
        // Check factory tracking
        assertTrue(factory.isVault(vault));
        assertEq(factory.getVaultCount(), 1);
        assertEq(factory.getVault(0), vault);
        
        address[] memory allVaults = factory.getAllVaults();
        assertEq(allVaults.length, 1);
        assertEq(allVaults[0], vault);
    }

    function testCreateVaultZeroAddresses() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.createVault(
            address(0), // zero base
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.createVault(
            address(baseToken),
            address(0), // zero quote
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );
    }

    function testCreateVaultSameTokens() public {
        vm.expectRevert(Errors.InvalidParams.selector);
        factory.createVault(
            address(baseToken),
            address(baseToken), // same as base
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );
    }

    function testCreateVaultInvalidParams() public {
        vm.expectRevert(Errors.InvalidParams.selector);
        factory.createVault(
            address(baseToken),
            address(quoteToken),
            0, // zero interval
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        vm.expectRevert(Errors.InvalidParams.selector);
        factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            10001, // > 100%
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        vm.expectRevert(Errors.InvalidParams.selector);
        factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            10001, // > 100%
            keeper
        );
    }

    function testCreateVaultEvent() public {
        vm.expectEmit(true, true, true, true);
        emit VaultCreated(address(0), address(baseToken), address(quoteToken), user1);

        vm.prank(user1);
        factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );
    }

    function testCopyVault() public {
        // Create original vault
        vm.prank(user1);
        address originalVault = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        // Copy vault
        vm.prank(user2);
        address copiedVault = factory.copyVault(originalVault);

        // Check copied vault
        MicroDcaVault original = MicroDcaVault(originalVault);
        MicroDcaVault copy = MicroDcaVault(copiedVault);

        // Should have same configuration
        assertEq(address(copy.baseToken()), address(original.baseToken()));
        assertEq(address(copy.quoteToken()), address(original.quoteToken()));
        assertEq(copy.intervalSeconds(), original.intervalSeconds());
        
        (uint256 origInterval, uint256 origSlippage, uint256 origCap, uint256 origFee,,) = original.getConfig();
        (uint256 copyInterval, uint256 copySlippage, uint256 copyCap, uint256 copyFee,,) = copy.getConfig();
        
        assertEq(copyInterval, origInterval);
        assertEq(copySlippage, origSlippage);
        assertEq(copyCap, origCap);
        assertEq(copyFee, origFee);

        // But different owner (user2 instead of user1)
        assertEq(copy.owner(), user2);
        assertNotEq(copy.owner(), original.owner());

        // Check factory tracking
        assertTrue(factory.isVault(copiedVault));
        assertEq(factory.getVaultCount(), 2);
    }

    function testCopyVaultZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.copyVault(address(0));
    }

    function testCopyVaultInvalidAddress() public {
        vm.expectRevert(Errors.InvalidParams.selector);
        factory.copyVault(makeAddr("notAVault"));
    }

    function testCopyVaultEvent() public {
        // Create original vault
        vm.prank(user1);
        address originalVault = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            keeper
        );

        vm.expectEmit(true, true, true, true);
        emit VaultCopied(originalVault, address(0), user2);

        // Copy vault
        vm.prank(user2);
        factory.copyVault(originalVault);
    }

    function testGetVaultsPaginated() public {
        address[] memory vaults = new address[](5);

        // Create 5 vaults
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            vaults[i] = factory.createVault(
                address(baseToken),
                address(quoteToken),
                INTERVAL + i, // Slightly different configs
                MAX_SLIPPAGE_BPS,
                PER_CYCLE_CAP,
                FEE_BPS,
                keeper
            );
        }

        // Test pagination
        (address[] memory page1, uint256 total) = factory.getVaultsPaginated(0, 3);
        assertEq(total, 5);
        assertEq(page1.length, 3);
        assertEq(page1[0], vaults[0]);
        assertEq(page1[1], vaults[1]);
        assertEq(page1[2], vaults[2]);

        (address[] memory page2,) = factory.getVaultsPaginated(3, 3);
        assertEq(page2.length, 2);
        assertEq(page2[0], vaults[3]);
        assertEq(page2[1], vaults[4]);

        // Test offset beyond bounds
        (address[] memory emptyPage,) = factory.getVaultsPaginated(10, 3);
        assertEq(emptyPage.length, 0);
    }

    function testGetVaultOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        factory.getVault(0);
    }

    function testMultipleUsersCreateVaults() public {
        // User1 creates vault
        vm.prank(user1);
        address vault1 = factory.createVault(
            address(baseToken),
            address(quoteToken),
            INTERVAL,
            MAX_SLIPPAGE_BPS,
            PER_CYCLE_CAP,
            FEE_BPS,
            address(0)
        );

        // User2 creates vault with different tokens
        vm.prank(user2);
        address vault2 = factory.createVault(
            address(baseToken2),
            address(quoteToken2),
            INTERVAL * 2,
            MAX_SLIPPAGE_BPS * 2,
            PER_CYCLE_CAP * 2,
            FEE_BPS * 2,
            keeper
        );

        // Check both vaults exist and have correct owners
        assertEq(MicroDcaVault(vault1).owner(), user1);
        assertEq(MicroDcaVault(vault2).owner(), user2);
        
        assertTrue(factory.isVault(vault1));
        assertTrue(factory.isVault(vault2));
        assertEq(factory.getVaultCount(), 2);

        // User2 copies user1's vault
        vm.prank(user2);
        address vault3 = factory.copyVault(vault1);
        
        // Should have user2 as owner but user1's config
        assertEq(MicroDcaVault(vault3).owner(), user2);
        assertEq(address(MicroDcaVault(vault3).baseToken()), address(baseToken));
        assertEq(address(MicroDcaVault(vault3).quoteToken()), address(quoteToken));
    }
}
