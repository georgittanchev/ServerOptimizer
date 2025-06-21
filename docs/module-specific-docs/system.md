# System Module

## Overview
The System Module provides functions for optimizing Linux system settings including kernel parameters, resource limits, and network configuration. It applies performance-focused configurations scaled appropriately for different server types.

## Features

### System Limits Configuration
- Optimizes critical system limits based on server resources
- Configures process limits (/etc/security/limits.conf):
  - File descriptor limits (nofile)
  - Process count limits (nproc)
  - Memory lock limits (memlock)
- Scales limits appropriately for both regular users and root

### Kernel Parameter Optimization
- Configures memory management parameters:
  - Adaptive swappiness based on available RAM
  - Memory overcommit settings for optimal application performance
  - Reserved memory calculations for system stability
  - Dirty page ratio for optimal I/O performance
- Optimizes network stack for high throughput:
  - TCP buffer sizes and connection parameters
  - BBR congestion control for improved throughput
  - Connection tracking optimizations
  - Enhanced TCP parameters for server workloads
- Sets appropriate file system limits for busy servers
- Disables Transparent Huge Pages for database workloads

### IPv6 Management
- Provides options to disable IPv6 when not needed
- Applies IPv6 configuration changes safely through sysctl
- Verifies IPv6 settings are properly applied

## Requirements
- Root access to the server
- Linux kernel 3.10 or newer (for BBR congestion control)
- sysctl and limits.conf configuration capabilities

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/system.sh

# Run through the main optimizer
./optimize.sh --module system
```

## Technical Notes
- Scales resource limits based on detected CPU cores and RAM
- Calculates appropriate connection tracking limits based on server type
- Creates backups of all configuration files before modification
- Maintains persistent configuration through system reboots
- Applies changes safely with fallback mechanisms if issues occur
