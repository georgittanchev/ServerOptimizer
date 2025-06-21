# LSAPI Module

## Overview
The LSAPI Module provides functions for installing and configuring LiteSpeed API (LSAPI) to significantly improve PHP performance in cPanel environments. It analyzes server resources and PHP memory requirements to create optimal configurations.

## Features

### PHP Memory Analysis
- Scans all domains on the server to analyze PHP memory usage
- Detects custom memory limits from php.ini and .user.ini files
- Calculates optimal memory settings based on actual website requirements
- Generates detailed reports with per-domain memory usage
- Provides PHP version distribution statistics

### Intelligent LSAPI Configuration
- Calculates optimal settings based on server type and resources
- Configures LSAPI with resource-appropriate settings:
  - Process pool size
  - Memory limits per process
  - Idle timeouts
  - Request limits
  - Connection parameters
- Supports both VPS and dedicated server environments
- Automatically scales settings based on CPU cores and available RAM

### LSAPI Installation and Setup
- Installs mod_lsapi from LiteSpeed repositories
- Configures LSAPI with optimized settings for the specific server
- Creates necessary directories for logs and core dumps
- Implements monitoring services for crash detection
- Sets up proper security parameters

### LSAPI Monitoring
- Creates a systemd service for continuous LSAPI monitoring
- Detects and alerts on excessive crashes or respawns
- Establishes proper logging for troubleshooting
- Monitors for performance and stability issues

## Requirements
- cPanel server with Apache
- Root access to the server
- WP-CLI for WordPress performance optimization

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/lsapi.sh

# Run through the main optimizer
./optimize.sh --module lsapi
```

## Technical Notes
- Calculates optimal children count based on CPU cores and available memory
- Uses memory analysis to determine ideal process memory limits
- Configures Apache appropriately for optimal LSAPI operation
- Creates detailed logs and monitoring systems for ongoing stability
