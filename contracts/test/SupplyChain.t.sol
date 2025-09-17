// SPDX-License-Identifier: MIT
pragma solidity 0.8.^19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SupplyChain.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Supply Chain Contract Test Suite
/// @notice Comprehensive tests for SupplyChain contract using Foundry
/// @dev Tests cover happy paths, edge cases, access control, and gas optimization
contract SupplyChainTest is Test {
    // Contract instances
    SupplyChain public supplyChain;
    SupplyChain public implementation;
    ERC1967Proxy public proxy;

    // Test addresses
    address public admin = makeAddr("admin");
    address public manufacturer = makeAddr("manufacturer");
    address public distributor = makeAddr("distributor");
    address public retailer = makeAddr("retailer");
    address public unauthorized = makeAddr("unauthorized");

    // Test data
    bytes32 public constant TEST_PRODUCT_ID = keccak256("TEST_PRODUCT_001");
    bytes32 public constant TEST_PRODUCT_ID_2 = keccak256("TEST_PRODUCT_002");
    string public constant TEST_METADATA = "ipfs://QmTestHash123";
    string public constant TEST_LOCATION = "New York Warehouse";

    // Role constants
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    // Events for testing
    event ProductCreated(bytes32 indexed productId, address indexed manufacturer, string metadata, uint256 timestamp);
    event LocationUpdated(bytes32 indexed productId, address indexed updatedBy, string location, SupplyChain.ProductStatus status, uint256 timestamp);
    event StatusChanged(bytes32 indexed productId, SupplyChain.ProductStatus indexed oldStatus, SupplyChain.ProductStatus indexed newStatus, uint256 timestamp);

    function setUp() public {
        // Deploy implementation contract
        implementation = new SupplyChain();
        
        // Deploy proxy pointing to implementation
        bytes memory initData = abi.encodeWithSelector(
            SupplyChain.initialize.selector,
            admin
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        
        // Cast proxy to SupplyChain interface
        supplyChain = SupplyChain(address(proxy));

        // Setup roles
        vm.startPrank(admin);
        supplyChain.grantRole(MANUFACTURER_ROLE, manufacturer);
        supplyChain.grantRole(DISTRIBUTOR_ROLE, distributor);
        supplyChain.grantRole(RETAILER_ROLE, retailer);
        vm.stopPrank();
    }

    /// @notice Test contract initialization
    function test_Initialize() public {
        // Verify admin role
        assertTrue(supplyChain.hasRole(supplyChain.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(supplyChain.hasRole(MANUFACTURER_ROLE, admin));
        
        // Verify role assignments
        assertTrue(supplyChain.hasRole(MANUFACTURER_ROLE, manufacturer));
        assertTrue(supplyChain.hasRole(DISTRIBUTOR_ROLE, distributor));
        assertTrue(supplyChain.hasRole(RETAILER_ROLE, retailer));
        
        // Verify unauthorized users don't have roles
        assertFalse(supplyChain.hasRole(MANUFACTURER_ROLE, unauthorized));
    }

    /// @notice Test successful product creation
    function test_CreateProduct_Success() public {
        vm.startPrank(manufacturer);
        
        // Expect ProductCreated event
        vm.expectEmit(true, true, false, true);
        emit ProductCreated(TEST_PRODUCT_ID, manufacturer, TEST_METADATA, block.timestamp);
        
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Verify product data
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertEq(product.owner, manufacturer);
        assertEq(uint8(product.status), uint8(SupplyChain.ProductStatus.Created));
        assertTrue(product.exists);
        assertEq(product.metadata, TEST_METADATA);
        assertEq(product.createdAt, uint32(block.timestamp));
        
        // Verify tracking history
        SupplyChain.TrackingEvent[] memory history = supplyChain.getTrackingHistory(TEST_PRODUCT_ID);
        assertEq(history.length, 1);
        assertEq(history[0].updatedBy, manufacturer);
        assertEq(uint8(history[0].status), uint8(SupplyChain.ProductStatus.Created));
        
        vm.stopPrank();
    }

    /// @notice Test product creation access control
    function test_CreateProduct_AccessControl() public {
        // Non-manufacturer should fail
        vm.startPrank(unauthorized);
        vm.expectRevert();
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        vm.stopPrank();

        // Distributor should fail (doesn't have MANUFACTURER_ROLE)
        vm.startPrank(distributor);
        vm.expectRevert();
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        vm.stopPrank();
    }

    /// @notice Test duplicate product creation
    function test_CreateProduct_Duplicate() public {
        vm.startPrank(manufacturer);
        
        // Create first product
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Attempt to create duplicate
        vm.expectRevert(abi.encodeWithSelector(SupplyChain.ProductAlreadyExists.selector, TEST_PRODUCT_ID));
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        vm.stopPrank();
    }

    /// @notice Test empty metadata rejection
    function test_CreateProduct_EmptyMetadata() public {
        vm.startPrank(manufacturer);
        
        vm.expectRevert(SupplyChain.EmptyMetadata.selector);
        supplyChain.createProduct(TEST_PRODUCT_ID, "");
        
        vm.stopPrank();
    }

    /// @notice Test successful location update by manufacturer
    function test_UpdateLocation_ManufacturerToInTransit() public {
        // Setup: Create product
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Test: Update to InTransit
        vm.startPrank(manufacturer);
        
        vm.expectEmit(true, true, false, true);
        emit LocationUpdated(TEST_PRODUCT_ID, manufacturer, TEST_LOCATION, SupplyChain.ProductStatus.InTransit, block.timestamp);
        
        vm.expectEmit(true, true, true, true);
        emit StatusChanged(TEST_PRODUCT_ID, SupplyChain.ProductStatus.Created, SupplyChain.ProductStatus.InTransit, block.timestamp);
        
        supplyChain.updateLocation(TEST_PRODUCT_ID, TEST_LOCATION, SupplyChain.ProductStatus.InTransit);
        
        // Verify state change
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertEq(uint8(product.status), uint8(SupplyChain.ProductStatus.InTransit));
        
        // Verify tracking history
        SupplyChain.TrackingEvent[] memory history = supplyChain.getTrackingHistory(TEST_PRODUCT_ID);
        assertEq(history.length, 2);
        assertEq(history[1].location, TEST_LOCATION);
        assertEq(uint8(history[1].status), uint8(SupplyChain.ProductStatus.InTransit));
        
        vm.stopPrank();
    }

    /// @notice Test complete supply chain flow
    function test_CompleteSupplyChainFlow() public {
        // 1. Manufacturer creates product
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // 2. Manufacturer ships to distributor
        vm.prank(manufacturer);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "Shipping Facility", SupplyChain.ProductStatus.InTransit);
        
        // 3. Distributor receives product
        vm.prank(distributor);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "Distribution Center", SupplyChain.ProductStatus.AtDistributor);
        
        // 4. Distributor ships to retailer
        vm.prank(distributor);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "En Route to Retail", SupplyChain.ProductStatus.InTransit);
        
        // 5. Retailer receives product
        vm.prank(retailer);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "Retail Store", SupplyChain.ProductStatus.AtRetailer);
        
        // 6. Retailer sells product
        vm.prank(retailer);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "Sold to Customer", SupplyChain.ProductStatus.Sold);
        
        // Verify final state
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertEq(uint8(product.status), uint8(SupplyChain.ProductStatus.Sold));
        
        // Verify complete tracking history
        SupplyChain.TrackingEvent[] memory history = supplyChain.getTrackingHistory(TEST_PRODUCT_ID);
        assertEq(history.length, 6);
        assertEq(uint8(history[5].status), uint8(SupplyChain.ProductStatus.Sold));
    }

    /// @notice Test invalid status transitions
    function test_InvalidStatusTransitions() public {
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Manufacturer cannot skip to Sold directly
        vm.startPrank(manufacturer);
        vm.expectRevert(abi.encodeWithSelector(
            SupplyChain.InvalidStatusTransition.selector,
            SupplyChain.ProductStatus.Created,
            SupplyChain.ProductStatus.Sold
        ));
        supplyChain.updateLocation(TEST_PRODUCT_ID, TEST_LOCATION, SupplyChain.ProductStatus.Sold);
        vm.stopPrank();
        
        // Distributor cannot update Created status
        vm.startPrank(distributor);
        vm.expectRevert(abi.encodeWithSelector(
            SupplyChain.InvalidStatusTransition.selector,
            SupplyChain.ProductStatus.Created,
            SupplyChain.ProductStatus.AtDistributor
        ));
        supplyChain.updateLocation(TEST_PRODUCT_ID, TEST_LOCATION, SupplyChain.ProductStatus.AtDistributor);
        vm.stopPrank();
    }

    /// @notice Test ownership transfer
    function test_TransferOwnership() public {
        // Setup
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Transfer ownership
        vm.startPrank(manufacturer);
        supplyChain.transferOwnership(TEST_PRODUCT_ID, distributor);
        vm.stopPrank();
        
        // Verify ownership change
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertEq(product.owner, distributor);
    }

    /// @notice Test unauthorized ownership transfer
    function test_TransferOwnership_Unauthorized() public {
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        // Unauthorized user attempts transfer
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(
            SupplyChain.UnauthorizedTransfer.selector,
            unauthorized,
            manufacturer
        ));
        supplyChain.transferOwnership(TEST_PRODUCT_ID, unauthorized);
        vm.stopPrank();
    }

    /// @notice Test contract pause functionality
    function test_PauseUnpause() public {
        // Admin pauses contract
        vm.prank(admin);
        supplyChain.pause();
        
        // Operations should fail when paused
        vm.startPrank(manufacturer);
        vm.expectRevert("Pausable: paused");
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        vm.stopPrank();
        
        // Admin unpauses contract
        vm.prank(admin);
        supplyChain.unpause();
        
        // Operations should work again
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertTrue(product.exists);
    }

    /// @notice Test gas optimization for product creation
    function test_Gas_ProductCreation() public {
        vm.startPrank(manufacturer);
        
        uint256 gasBefore = gasleft();
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Gas should be reasonable (adjust threshold based on requirements)
        console.log("Gas used for product creation:", gasUsed);
        assertLt(gasUsed, 200000); // Should use less than 200k gas
        
        vm.stopPrank();
    }

    /// @notice Test querying non-existent product
    function test_GetProduct_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(SupplyChain.ProductNotFound.selector, TEST_PRODUCT_ID));
        supplyChain.getProduct(TEST_PRODUCT_ID);
    }

    /// @notice Test empty location update
    function test_UpdateLocation_EmptyLocation() public {
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        
        vm.startPrank(manufacturer);
        vm.expectRevert(SupplyChain.EmptyLocation.selector);
        supplyChain.updateLocation(TEST_PRODUCT_ID, "", SupplyChain.ProductStatus.InTransit);
        vm.stopPrank();
    }

    /// @notice Test role constants
    function test_RoleConstants() public {
        assertEq(supplyChain.MANUFACTURER_ROLE(), MANUFACTURER_ROLE);
        assertEq(supplyChain.DISTRIBUTOR_ROLE(), DISTRIBUTOR_ROLE);
        assertEq(supplyChain.RETAILER_ROLE(), RETAILER_ROLE);
    }

    /// @notice Test multiple products tracking
    function test_MultipleProducts() public {
        vm.startPrank(manufacturer);
        
        // Create multiple products
        supplyChain.createProduct(TEST_PRODUCT_ID, TEST_METADATA);
        supplyChain.createProduct(TEST_PRODUCT_ID_2, "ipfs://QmTestHash456");
        
        // Verify both exist independently
        SupplyChain.Product memory product1 = supplyChain.getProduct(TEST_PRODUCT_ID);
        SupplyChain.Product memory product2 = supplyChain.getProduct(TEST_PRODUCT_ID_2);
        
        assertTrue(product1.exists);
        assertTrue(product2.exists);
        assertEq(product1.metadata, TEST_METADATA);
        assertEq(product2.metadata, "ipfs://QmTestHash456");
        
        vm.stopPrank();
    }

    /// @notice Fuzz test for product creation with various metadata
    function testFuzz_CreateProduct(string memory metadata) public {
        vm.assume(bytes(metadata).length > 0);
        vm.assume(bytes(metadata).length < 1000); // Reasonable size limit
        
        vm.prank(manufacturer);
        supplyChain.createProduct(TEST_PRODUCT_ID, metadata);
        
        SupplyChain.Product memory product = supplyChain.getProduct(TEST_PRODUCT_ID);
        assertEq(product.metadata, metadata);
    }
}