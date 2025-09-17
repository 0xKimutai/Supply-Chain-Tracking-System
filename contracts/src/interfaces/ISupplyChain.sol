// SPDX-License-Identifier: MIT
pragma solidity 0.8.^19;

/// @title Supply Chain Interface
/// @notice Defines the standard interface for supply chain tracking contracts
/// @dev Interface follows EIP-165 standard for contract introspection
interface ISupplyChain {
    // Custom errors
    error ProductAlreadyExists(bytes32 productId);
    error ProductNotFound(bytes32 productId);
    error InvalidStatusTransition(ProductStatus from, ProductStatus to);
    error UnauthorizedTransfer(address caller, address owner);
    error EmptyLocation();
    error EmptyMetadata();

    // Product status enumeration
    enum ProductStatus {
        Created,
        InTransit,
        AtDistributor,
        AtRetailer,
        Sold
    }

    // Product data structure
    struct Product {
        address owner;
        uint32 createdAt;
        uint32 lastUpdated;
        ProductStatus status;
        bool exists;
        string metadata;
    }

    // Tracking event structure
    struct TrackingEvent {
        address updatedBy;
        string location;
        uint32 timestamp;
        ProductStatus status;
    }

    // Events
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

    // Core functions
    
    /// @notice Create a new product in the supply chain
    /// @param productId Unique identifier for the product
    /// @param metadata IPFS hash or JSON string with product details
    function createProduct(bytes32 productId, string calldata metadata) external;

    /// @notice Update product location and status
    /// @param productId Product to update
    /// @param location New location description
    /// @param newStatus New status of the product
    function updateLocation(
        bytes32 productId,
        string calldata location,
        ProductStatus newStatus
    ) external;

    /// @notice Transfer product ownership
    /// @param productId Product to transfer
    /// @param newOwner New owner address
    function transferOwnership(bytes32 productId, address newOwner) external;

    /// @notice Get product information
    /// @param productId Product identifier
    /// @return Product struct data
    function getProduct(bytes32 productId) external view returns (Product memory);

    /// @notice Get complete tracking history for a product
    /// @param productId Product identifier
    /// @return Array of tracking events
    function getTrackingHistory(bytes32 productId) external view returns (TrackingEvent[] memory);

    // Role constants
    function MANUFACTURER_ROLE() external pure returns (bytes32);
    function DISTRIBUTOR_ROLE() external pure returns (bytes32);
    function RETAILER_ROLE() external pure returns (bytes32);
}