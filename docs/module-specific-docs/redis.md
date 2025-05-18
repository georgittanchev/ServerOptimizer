# Redis Module

## Overview
The Redis Module provides functions for installing, configuring, and optimizing Redis on cPanel servers. It automatically scales Redis settings based on server resources and installs the necessary PHP extensions for integration with websites.

## Features

### Adaptive Redis Memory Calculation
- Calculates optimal Redis memory allocation based on server type and available RAM
- Accounts for MySQL memory usage to prevent resource contention
- Scales Redis memory proportionally with server size:
  - 15% of available RAM for small servers (2-4GB)
  - 20% of available RAM for medium servers (4-8GB)
  - 25% of available RAM for larger servers (8-16GB)
  - 30% of available RAM for high-end servers (16-32GB)
  - 35% of available RAM for enterprise servers (32GB+)
- Enforces minimum (256MB) and maximum (16GB) memory limits

### Redis Installation and Configuration
- Installs Redis from the Remi repository for optimal compatibility
- Creates an optimized Redis configuration with:
  - Memory management settings (maxmemory and eviction policy)
  - Performance tuning parameters
  - Connection management settings
  - Database limit configurations
- Creates proper data directories with appropriate permissions
- Enables and configures Redis as a system service

### PHP Integration
- Automatically installs Redis PHP extensions for all installed PHP versions
- Installs igbinary for more efficient serialization
- Intelligently skips incompatible PHP versions (< 7.2)
- Handles appropriate PHP version detection via cPanel

## Requirements
- cPanel server with RHEL/CentOS 7/8/9
- Root access
- Sufficient RAM for Redis cache allocation

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/redis.sh

# Run through the main optimizer
./optimize.sh --module redis
```

## Technical Notes
- Creates backups of the original Redis configuration files
- Properly handles error conditions with restore functionality
- Can detect server type from MySQL configuration if available
- Configures Redis with LRU eviction policy for optimal caching
- Integrates with the WordPress module for full-stack caching solutions
