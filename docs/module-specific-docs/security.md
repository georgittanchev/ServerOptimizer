# Security Module

## Overview
The Security Module provides functions for enhancing server security through various mechanisms. It focuses on protecting web servers from malicious traffic and common attack vectors.

## Features

### Bad Bot Blocker
- Implements Apache Ultimate Bad Bot Blocker to filter malicious traffic
- Automatically installs and configures required files
- Creates Cloudflare IP whitelist for seamless CDN integration
- Adds server IPs to whitelist to prevent self-blocking
- Creates domain whitelist based on WHM API data
- Properly configures Apache to use the Bad Bot Blocker ruleset

## Requirements
- Apache 2.4 webserver
- Root access to server
- Optional: WHM/cPanel for automatic domain whitelisting

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/security.sh

# Run through the main optimizer
./optimize.sh --module security
```

## Configuration Options
The module uses default configuration paths for Apache but can be modified in the script variables if needed.

## Technical Notes
- Whitelist files are automatically created with server-specific information
- Apache configuration is updated with proper directory permissions
- Configuration backups are created before making changes
- Apache is restarted after configuration to apply changes
