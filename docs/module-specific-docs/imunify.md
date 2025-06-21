# Imunify Module

## Overview
The Imunify Module provides functions for optimizing Imunify360 settings on cPanel servers. It configures the security software to reduce resource usage while maintaining effective protection.

## Features

### Imunify360 Optimization
- Reduces scanning intensity to minimize I/O and CPU impact
- Enables automatic malicious file restoration from backups
- Disables CAPTCHA DOS protection to prevent service interference
- Disables WebShield for better compatibility with other proxies (e.g., Engintron)
- Disables WebShield known proxies support
- Disables ModSecurity block by severity feature
- Restarts the service to apply all changes

## Requirements
- Imunify360 must be installed on the server
- cPanel/WHM environment
- Root access to the server

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/imunify.sh

# Run through the main optimizer
./optimize.sh --module imunify
```

## Technical Notes
- Automatically checks if Imunify360 is installed before attempting optimization
- Provides detailed logging of configuration changes
- Reports success/failure for each configuration change
- Safely restarts the Imunify360 service after applying changes
