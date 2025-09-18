// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Supply Chain Events Library
/// @notice Centralized event definitions for supply chain operations
/// @dev Provides standardized events for tracking and analytics
library SupplyChainEvents {
    // Product lifecycle events

    /// @notice Emitted when a new product is created
    /// @param productId Unique product identifier
    /// @param manufacturer Address of the manufacturing entity
    /// @param metadata Product metadata (IPFS hash or JSON)
    /// @param timestamp Block timestamp of creation
    event ProductCreated(bytes32 indexed productId, address indexed manufacturer, string metadata, uint256 timestamp);

    /// @notice Emitted when product ownership is transferred
    /// @param productId Product being transferred
    /// @param from Previous owner address
    /// @param to New owner address
    /// @param status Current product status
    /// @param timestamp Block timestamp of transfer
    event ProductTransferred(
        bytes32 indexed productId, address indexed from, address indexed to, ProductStatus status, uint256 timestamp
    );

    /// @notice Emitted when product location is updated
    /// @param productId Product being updated
    /// @param updatedBy Address performing the update
    /// @param location New location description
    /// @param status New product status
    /// @param timestamp Block timestamp of update
    event LocationUpdated(
        bytes32 indexed productId, address indexed updatedBy, string location, ProductStatus status, uint256 timestamp
    );

    /// @notice Emitted when product status changes
    /// @param productId Product with status change
    /// @param oldStatus Previous status
    /// @param newStatus New status
    /// @param timestamp Block timestamp of change
    event StatusChanged(
        bytes32 indexed productId, ProductStatus indexed oldStatus, ProductStatus indexed newStatus, uint256 timestamp
    );

    // Batch operation events

    /// @notice Emitted when multiple products are updated in a single transaction
    /// @param productIds Array of product identifiers
    /// @param updatedBy Address performing batch update
    /// @param location New location for all products
    /// @param newStatus New status for all products
    /// @param timestamp Block timestamp of batch update
    event BatchLocationUpdated(
        bytes32[] indexed productIds,
        address indexed updatedBy,
        string location,
        ProductStatus newStatus,
        uint256 timestamp
    );

    // Administrative events

    /// @notice Emitted when a new role is granted to an address
    /// @param role Role identifier (keccak256 hash)
    /// @param account Address receiving the role
    /// @param sender Address granting the role
    /// @param timestamp Block timestamp of role grant
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender, uint256 timestamp);

    /// @notice Emitted when a role is revoked from an address
    /// @param role Role identifier (keccak256 hash)
    /// @param account Address losing the role
    /// @param sender Address revoking the role
    /// @param timestamp Block timestamp of role revocation
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender, uint256 timestamp);

    /// @notice Emitted when contract is paused
    /// @param account Address that triggered the pause
    /// @param timestamp Block timestamp of pause
    event ContractPaused(address indexed account, uint256 timestamp);

    /// @notice Emitted when contract is unpaused
    /// @param account Address that triggered the unpause
    /// @param timestamp Block timestamp of unpause
    event ContractUnpaused(address indexed account, uint256 timestamp);

    // Quality and compliance events

    /// @notice Emitted when a quality check is performed
    /// @param productId Product being inspected
    /// @param inspector Address performing inspection
    /// @param passed Whether the quality check passed
    /// @param notes Additional inspection notes
    /// @param timestamp Block timestamp of inspection
    event QualityCheck(
        bytes32 indexed productId, address indexed inspector, bool indexed passed, string notes, uint256 timestamp
    );

    /// @notice Emitted when a product recall is initiated
    /// @param productIds Array of products being recalled
    /// @param reason Reason for the recall
    /// @param initiator Address initiating the recall
    /// @param severity Recall severity level (1=low, 5=critical)
    /// @param timestamp Block timestamp of recall initiation
    event ProductRecall(
        bytes32[] indexed productIds, string reason, address indexed initiator, uint8 severity, uint256 timestamp
    );

    // Temperature and environmental tracking events

    /// @notice Emitted when environmental conditions are recorded
    /// @param productId Product with environmental data
    /// @param temperature Temperature in Celsius * 100 (for 2 decimal precision)
    /// @param humidity Humidity percentage * 100 (for 2 decimal precision)
    /// @param location Location where measurement was taken
    /// @param sensor Address of IoT sensor or recording device
    /// @param timestamp Block timestamp of measurement
    event EnvironmentalConditions(
        bytes32 indexed productId,
        int16 temperature,
        uint16 humidity,
        string location,
        address indexed sensor,
        uint256 timestamp
    );

    // Product status enumeration (duplicated for library independence)
    enum ProductStatus {
        Created,
        InTransit,
        AtDistributor,
        AtRetailer,
        Sold
    }

    // Event emission helper functions

    /// @notice Helper to emit product created event with current timestamp
    /// @param productId Product identifier
    /// @param manufacturer Manufacturing address
    /// @param metadata Product metadata
    function emitProductCreated(bytes32 productId, address manufacturer, string memory metadata) internal {
        emit ProductCreated(productId, manufacturer, metadata, block.timestamp);
    }

    /// @notice Helper to emit location updated event with current timestamp
    /// @param productId Product identifier
    /// @param updatedBy Address performing update
    /// @param location New location
    /// @param status New status
    function emitLocationUpdated(bytes32 productId, address updatedBy, string memory location, ProductStatus status)
        internal
    {
        emit LocationUpdated(productId, updatedBy, location, status, block.timestamp);
    }

    /// @notice Helper to emit status changed event with current timestamp
    /// @param productId Product identifier
    /// @param oldStatus Previous status
    /// @param newStatus New status
    function emitStatusChanged(bytes32 productId, ProductStatus oldStatus, ProductStatus newStatus) internal {
        emit StatusChanged(productId, oldStatus, newStatus, block.timestamp);
    }

    /// @notice Helper to emit environmental conditions with current timestamp
    /// @param productId Product identifier
    /// @param temperature Temperature reading
    /// @param humidity Humidity reading
    /// @param location Measurement location
    /// @param sensor Sensor address
    function emitEnvironmentalConditions(
        bytes32 productId,
        int16 temperature,
        uint16 humidity,
        string memory location,
        address sensor
    ) internal {
        emit EnvironmentalConditions(productId, temperature, humidity, location, sensor, block.timestamp);
    }
}
