// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title Supply Chain Tracking System
/// @notice Tracks products through supply chain with role-based access control
/// @dev Implements upgradeable pattern with comprehensive access controls
contract SupplyChain is 
    Initializable, 
    AccessControlUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // Custom errors for gas efficiency
    error ProductAlreadyExists(bytes32 productId);
    error ProductNotFound(bytes32 productId);
    error InvalidStatusTransition(ProductStatus from, ProductStatus to);
    error UnauthorizedTransfer(address caller, address owner);
    error EmptyLocation();
    error EmptyMetadata();

    // Role definitions
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    // Product status enumeration
    enum ProductStatus {
        Created,        // 0 - Just manufactured
        InTransit,      // 1 - Being shipped
        AtDistributor,  // 2 - At distribution center
        AtRetailer,     // 3 - At retail location
        Sold           // 4 - Sold to end consumer
    }

    // Optimized struct for storage efficiency (fits in 2 storage slots)
    struct Product {
        address owner;          // 20 bytes
        uint32 createdAt;       // 4 bytes (packed with address)
        uint32 lastUpdated;     // 4 bytes
        ProductStatus status;   // 1 byte (packed)
        bool exists;           // 1 byte (packed)
        string metadata;       // Dynamic - separate slot
    }

    struct TrackingEvent {
        address updatedBy;
        string location;
        uint32 timestamp;
        ProductStatus status;
    }

    // State variables
    mapping(bytes32 => Product) private products;
    mapping(bytes32 => TrackingEvent[]) private trackingHistory;
    
    // Events with proper indexing for efficient filtering
    event ProductCreated(
        bytes32 indexed productId,
        address indexed manufacturer,
        string metadata,
        uint256 timestamp
    );

    event ProductTransferred(
        bytes32 indexed productId,
        address indexed from,
        address indexed to,
        ProductStatus status,
        uint256 timestamp
    );

    event LocationUpdated(
        bytes32 indexed productId,
        address indexed updatedBy,
        string location,
        ProductStatus status,
        uint256 timestamp
    );

    event StatusChanged(
        bytes32 indexed productId,
        ProductStatus indexed oldStatus,
        ProductStatus indexed newStatus,
        uint256 timestamp
    );

    /// @notice Initialize the contract (replaces constructor for upgradeable contracts)
    /// @param admin Address that will have admin role
    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANUFACTURER_ROLE, admin);
    }

    /// @notice Create a new product in the supply chain
    /// @param productId Unique identifier for the product
    /// @param metadata IPFS hash or JSON string with product details
    function createProduct(
        bytes32 productId,
        string calldata metadata
    ) external whenNotPaused onlyRole(MANUFACTURER_ROLE) {
        if (products[productId].exists) {
            revert ProductAlreadyExists(productId);
        }
        if (bytes(metadata).length == 0) {
            revert EmptyMetadata();
        }

        uint32 timestamp = uint32(block.timestamp);
        
        products[productId] = Product({
            owner: msg.sender,
            createdAt: timestamp,
            lastUpdated: timestamp,
            status: ProductStatus.Created,
            exists: true,
            metadata: metadata
        });

        // Add initial tracking event
        trackingHistory[productId].push(TrackingEvent({
            updatedBy: msg.sender,
            location: "Manufacturing Facility",
            timestamp: timestamp,
            status: ProductStatus.Created
        }));

        emit ProductCreated(productId, msg.sender, metadata, block.timestamp);
    }

    /// @notice Update product location and status
    /// @param productId Product to update
    /// @param location New location description
    /// @param newStatus New status of the product
    function updateLocation(
        bytes32 productId,
        string calldata location,
        ProductStatus newStatus
    ) external whenNotPaused nonReentrant {
        Product storage product = products[productId];
        
        if (!product.exists) {
            revert ProductNotFound(productId);
        }
        if (bytes(location).length == 0) {
            revert EmptyLocation();
        }
        if (!_canUpdateStatus(msg.sender, product.status, newStatus)) {
            revert InvalidStatusTransition(product.status, newStatus);
        }

        ProductStatus oldStatus = product.status;
        product.status = newStatus;
        product.lastUpdated = uint32(block.timestamp);

        // Add tracking event
        trackingHistory[productId].push(TrackingEvent({
            updatedBy: msg.sender,
            location: location,
            timestamp: uint32(block.timestamp),
            status: newStatus
        }));

        emit LocationUpdated(productId, msg.sender, location, newStatus, block.timestamp);
        
        if (oldStatus != newStatus) {
            emit StatusChanged(productId, oldStatus, newStatus, block.timestamp);
        }
    }

    /// @notice Transfer product ownership
    /// @param productId Product to transfer
    /// @param newOwner New owner address
    function transferOwnership(
        bytes32 productId,
        address newOwner
    ) external whenNotPaused {
        Product storage product = products[productId];
        
        if (!product.exists) {
            revert ProductNotFound(productId);
        }
        if (product.owner != msg.sender && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedTransfer(msg.sender, product.owner);
        }

        address oldOwner = product.owner;
        product.owner = newOwner;
        product.lastUpdated = uint32(block.timestamp);

        emit ProductTransferred(productId, oldOwner, newOwner, product.status, block.timestamp);
    }

    /// @notice Get product information
    /// @param productId Product identifier
    /// @return Product struct data
    function getProduct(bytes32 productId) external view returns (Product memory) {
        if (!products[productId].exists) {
            revert ProductNotFound(productId);
        }
        return products[productId];
    }

    /// @notice Get complete tracking history for a product
    /// @param productId Product identifier
    /// @return Array of tracking events
    function getTrackingHistory(bytes32 productId) external view returns (TrackingEvent[] memory) {
        if (!products[productId].exists) {
            revert ProductNotFound(productId);
        }
        return trackingHistory[productId];
    }

    /// @notice Check if a status transition is valid for the caller
    /// @param caller Address attempting the update
    /// @param currentStatus Current product status
    /// @param newStatus Desired new status
    /// @return bool Whether the transition is allowed
    function _canUpdateStatus(
        address caller,
        ProductStatus currentStatus,
        ProductStatus newStatus
    ) private view returns (bool) {
        // Manufacturers can move from Created to InTransit
        if (hasRole(MANUFACTURER_ROLE, caller)) {
            return currentStatus == ProductStatus.Created && newStatus == ProductStatus.InTransit;
        }
        
        // Distributors can update InTransit and AtDistributor
        if (hasRole(DISTRIBUTOR_ROLE, caller)) {
            return (currentStatus == ProductStatus.InTransit && newStatus == ProductStatus.AtDistributor) ||
                   (currentStatus == ProductStatus.AtDistributor && newStatus == ProductStatus.InTransit);
        }
        
        // Retailers can update AtRetailer and Sold
        if (hasRole(RETAILER_ROLE, caller)) {
            return (currentStatus == ProductStatus.InTransit && newStatus == ProductStatus.AtRetailer) ||
                   (currentStatus == ProductStatus.AtRetailer && newStatus == ProductStatus.Sold);
        }
        
        return false;
    }

    /// @notice Pause contract operations (admin only)
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause contract operations (admin only)
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}