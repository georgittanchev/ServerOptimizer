# Apache Module

## Overview
The Apache Module provides functions for optimizing Apache web server settings and performance. It includes MPM switching and comprehensive resource configuration tuned to specific server types.

## Features

### MPM Switching
- Converts Apache from worker MPM to event MPM for better performance
- Safely removes worker MPM package and installs event MPM
- Verifies successful MPM switch and module loading
- Ensures Apache runs with the event MPM for optimal performance

### Server-Specific Apache Optimization
- Configures Apache settings based on server resources and type
- Supports a wide range of server types:
  - VPS1 through VPS8 (Virtual Private Servers with increasing resources)
  - DSCPU1 through DSCPU9 (Dedicated Servers with increasing resources)
  - Those are based on the Linode shared and dedicated servers listed here:
  https://www.linode.com/pricing/
- Optimizes key Apache parameters:
  - MaxClients (maximum simultaneous connections)
  - MaxKeepAliveRequests (connection reuse limit)
  - MaxRequestsPerChild (process recycling)
  - KeepAlive (connection persistence)
  - ServerLimit (process count limit)
  - Timeout (connection timeout)
  - CPU and memory resource limits

### Configuration Management
- Creates backups of existing Apache configuration
- Uses jq for reliable configuration file manipulation
- Updates only existing parameters in the configuration file
- Reports detailed configuration changes for verification
- Restarts Apache to apply changes when appropriate

## Requirements
- cPanel server with EA4 Apache
- Root access for package management
- jq package (installed automatically if not present)

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/apache.sh

# Run through the main optimizer
./optimize.sh --module apache
```

## Technical Notes
- Scales process and connection limits based on available RAM and CPU
- Adjusts memory limits using appropriate KB values for Apache
- Safely handles error cases with relevant error reporting
- Maintains consistent server performance by appropriately scaling parameters
- Creates detailed logs for all optimization steps
