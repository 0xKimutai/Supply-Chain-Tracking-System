// SPDX-License-Identifier: MIT
pragma solidity 0.8.^19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SupplyChain.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @title Supply Chain Deployment Script
/// @notice Handles deployment of SupplyChain contract with proxy pattern
/// @dev Supports multiple networks and environments with proper verification
contract DeploySupplyChain is Script {
    // Deployment configuration
    struct DeploymentConfig {
        address admin;
        address[] manufacturers;
        address[] distributors;
        address[] retailers;
        bool verifyContracts;
        string network;
    }

    // Contract instances
    SupplyChain public implementation;
    ERC1967Proxy public proxy;
    SupplyChain public supplyChain;

    // Role constants
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    // Events
    event ContractsDeployed(
        address indexed implementation,
        address indexed proxy,
        address indexed admin
    );
    
    event RoleConfigured(
        bytes32 indexed role,
        address[] accounts
    );

    /// @notice Main deployment function
    /// @dev Deploys implementation, proxy, and configures roles
    function run() external {
        DeploymentConfig memory config = getDeploymentConfig();
        
        console.log("Starting deployment on network:", config.network);
        console.log("Admin address:", config.admin);
        
        vm.startBroadcast();
        
        // Deploy contracts
        _deployContracts(config);
        
        // Configure roles
        _configureRoles(config);
        
        // Verify deployment
        _verifyDeployment(config);
        
        vm.stopBroadcast();
        
        // Post-deployment verification
        if (config.verifyContracts) {
            _scheduleContractVerification();
        }
        
        _logDeploymentSummary(config);
    }

    /// @notice Deploy implementation and proxy contracts
    /// @param config Deployment configuration
    function _deployContracts(DeploymentConfig memory config) internal {
        console.log("Deploying SupplyChain implementation...");
        
        // Deploy implementation contract
        implementation = new SupplyChain();
        console.log("Implementation deployed at:", address(implementation));
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            SupplyChain.initialize.selector,
            config.admin
        );
        
        console.log("Deploying ERC1967 proxy...");
        
        // Deploy proxy contract
        proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed at:", address(proxy));
        
        // Cast proxy to SupplyChain interface
        supplyChain = SupplyChain(address(proxy));
        
        // Emit deployment event
        emit ContractsDeployed(address(implementation), address(proxy), config.admin);
        
        console.log("Contracts deployed successfully!");
    }

    /// @notice Configure roles for different parties
    /// @param config Deployment configuration with role assignments
    function _configureRoles(DeploymentConfig memory config) internal {
        console.log("Configuring roles...");
        
        // Configure manufacturer roles
        if (config.manufacturers.length > 0) {
            console.log("Granting MANUFACTURER_ROLE to", config.manufacturers.length, "accounts");
            for (uint256 i = 0; i < config.manufacturers.length; i++) {
                supplyChain.grantRole(MANUFACTURER_ROLE, config.manufacturers[i]);
                console.log("  - Granted to:", config.manufacturers[i]);
            }
            emit RoleConfigured(MANUFACTURER_ROLE, config.manufacturers);
        }
        
        // Configure distributor roles
        if (config.distributors.length > 0) {
            console.log("Granting DISTRIBUTOR_ROLE to", config.distributors.length, "accounts");
            for (uint256 i = 0; i < config.distributors.length; i++) {
                supplyChain.grantRole(DISTRIBUTOR_ROLE, config.distributors[i]);
                console.log("  - Granted to:", config.distributors[i]);
            }
            emit RoleConfigured(DISTRIBUTOR_ROLE, config.distributors);
        }
        
        // Configure retailer roles
        if (config.retailers.length > 0) {
            console.log("Granting RETAILER_ROLE to", config.retailers.length, "accounts");
            for (uint256 i = 0; i < config.retailers.length; i++) {
                supplyChain.grantRole(RETAILER_ROLE, config.retailers[i]);
                console.log("  - Granted to:", config.retailers[i]);
            }
            emit RoleConfigured(RETAILER_ROLE, config.retailers);
        }
        
        console.log("Role configuration completed!");
    }

    /// @notice Verify deployment was successful
    /// @param config Deployment configuration
    function _verifyDeployment(DeploymentConfig memory config) internal view {
        console.log("Verifying deployment...");
        
        // Verify proxy points to implementation
        address currentImpl = ERC1967Utils.getImplementation(address(proxy));
        require(currentImpl == address(implementation), "Proxy implementation mismatch");
        console.log("✓ Proxy correctly points to implementation");
        
        // Verify admin role
        require(supplyChain.hasRole(supplyChain.DEFAULT_ADMIN_ROLE(), config.admin), "Admin role not assigned");
        require(supplyChain.hasRole(MANUFACTURER_ROLE, config.admin), "Admin missing manufacturer role");
        console.log("✓ Admin roles configured correctly");
        
        // Verify contract is not paused
        require(!supplyChain.paused(), "Contract should not be paused after deployment");
        console.log("✓ Contract is active (not paused)");
        
        // Verify role counts
        console.log("✓ Configured", config.manufacturers.length, "manufacturers");
        console.log("✓ Configured", config.distributors.length, "distributors");
        console.log("✓ Configured", config.retailers.length, "retailers");
        
        console.log("Deployment verification completed successfully!");
    }

    /// @notice Get deployment configuration based on network
    /// @return config Deployment configuration for current network
    function getDeploymentConfig() public view returns (DeploymentConfig memory config) {
        string memory network = getNetworkName();
        
        if (compareStrings(network, "mainnet")) {
            config = getMainnetConfig();
        } else if (compareStrings(network, "sepolia")) {
            config = getSepoliaConfig();
        } else if (compareStrings(network, "polygon")) {
            config = getPolygonConfig();
        } else if (compareStrings(network, "localhost") || compareStrings(network, "anvil")) {
            config = getLocalConfig();
        } else {
            revert("Unsupported network");
        }
        
        config.network = network;
    }

    /// @notice Get mainnet deployment configuration
    /// @return config Mainnet-specific configuration
    function getMainnetConfig() internal pure returns (DeploymentConfig memory config) {
        config = DeploymentConfig({
            admin: 0x1234567890123456789012345678901234567890, // Replace with actual admin address
            manufacturers: new address[](0), // Configure in environment
            distributors: new address[](0),
            retailers: new address[](0),
            verifyContracts: true,
            network: ""
        });
    }

    /// @notice Get Sepolia testnet deployment configuration
    /// @return config Sepolia-specific configuration
    function getSepoliaConfig() internal view returns (DeploymentConfig memory config) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        config = DeploymentConfig({
            admin: deployer,
            manufacturers: _getEnvAddresses("MANUFACTURERS"),
            distributors: _getEnvAddresses("DISTRIBUTORS"),
            retailers: _getEnvAddresses("RETAILERS"),
            verifyContracts: vm.envBool("VERIFY_CONTRACTS"),
            network: ""
        });
    }

    /// @notice Get Polygon deployment configuration
    /// @return config Polygon-specific configuration
    function getPolygonConfig() internal view returns (DeploymentConfig memory config) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        config = DeploymentConfig({
            admin: deployer,
            manufacturers: _getEnvAddresses("MANUFACTURERS"),
            distributors: _getEnvAddresses("DISTRIBUTORS"),
            retailers: _getEnvAddresses("RETAILERS"),
            verifyContracts: true,
            network: ""
        });
    }

    /// @notice Get local development configuration
    /// @return config Local development configuration
    function getLocalConfig() internal view returns (DeploymentConfig memory config) {
        // Generate test addresses for local development
        address[] memory manufacturers = new address[](2);
        manufacturers[0] = makeAddr("manufacturer1");
        manufacturers[1] = makeAddr("manufacturer2");
        
        address[] memory distributors = new address[](2);
        distributors[0] = makeAddr("distributor1");
        distributors[1] = makeAddr("distributor2");
        
        address[] memory retailers = new address[](3);
        retailers[0] = makeAddr("retailer1");
        retailers[1] = makeAddr("retailer2");
        retailers[2] = makeAddr("retailer3");
        
        config = DeploymentConfig({
            admin: makeAddr("admin"),
            manufacturers: manufacturers,
            distributors: distributors,
            retailers: retailers,
            verifyContracts: false,
            network: ""
        });
    }

    /// @notice Get current network name
    /// @return Network identifier string
    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 137) return "polygon";
        if (chainId == 31337) return "localhost";
        
        return "unknown";
    }

    /// @notice Parse comma-separated addresses from environment variable
    /// @param envVar Environment variable name
    /// @return addresses Array of parsed addresses
    function _getEnvAddresses(string memory envVar) internal view returns (address[] memory addresses) {
        try vm.envString(envVar) returns (string memory addressesStr) {
            if (bytes(addressesStr).length == 0) {
                return new address[](0);
            }
            
            // Simple parsing for comma-separated addresses
            // In production, use more robust parsing
            string[] memory parts = vm.split(addressesStr, ",");
            addresses = new address[](parts.length);
            
            for (uint256 i = 0; i < parts.length; i++) {
                addresses[i] = vm.parseAddress(vm.trim(parts[i]));
            }
        } catch {
            return new address[](0);
        }
    }

    /// @notice Schedule contract verification on Etherscan
    /// @dev Called after deployment to verify source code
    function _scheduleContractVerification() internal {
        console.log("Scheduling contract verification...");
        console.log("Implementation contract:", address(implementation));
        console.log("Proxy contract:", address(proxy));
        
        // Note: Actual verification would be done via forge verify-contract command
        console.log("Run the following commands to verify contracts:");
        console.log("forge verify-contract", address(implementation), "SupplyChain", "--chain-id", block.chainid);
        console.log("forge verify-contract", address(proxy), "ERC1967Proxy", "--chain-id", block.chainid);
    }

    /// @notice Log deployment summary
    /// @param config Deployment configuration used
    function _logDeploymentSummary(DeploymentConfig memory config) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network:", config.network);
        console.log("Admin:", config.admin);
        console.log("Implementation:", address(implementation));
        console.log("Proxy (Main Contract):", address(proxy));
        console.log("Manufacturers:", config.manufacturers.length);
        console.log("Distributors:", config.distributors.length);
        console.log("Retailers:", config.retailers.length);
        console.log("Contract Verification:", config.verifyContracts ? "Enabled" : "Disabled");
        console.log("==========================\n");
        
        console.log("IMPORTANT: Save the proxy address for your applications:");
        console.log("SUPPLY_CHAIN_CONTRACT_ADDRESS=", address(proxy));
    }

    /// @notice Utility function to compare strings
    /// @param a First string
    /// @param b Second string
    /// @return True if strings are equal
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    /// @notice Generate deterministic address for testing
    /// @param name Address label
    /// @return Generated address
    function makeAddr(string memory name) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(name)))));
    }
}