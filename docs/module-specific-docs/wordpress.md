# WordPress Module

## Overview
The WordPress Module provides functions for optimizing WordPress installations by configuring Redis object caching integration, significantly improving WordPress performance by reducing database queries and caching PHP objects.

## Features

### WordPress Redis Integration
- Automatically scans the server for WordPress installations
- Installs the Redis Cache plugin on each WordPress site
- Configures wp-config.php with proper Redis connection settings
- Activates Redis object caching for each WordPress site
- Intelligently assigns unique Redis database numbers to prevent cache collisions
- Increases memory limit for WordPress during the installation process
- Skips plugin directories and incomplete WordPress installations

## Requirements
- Redis server must be installed and running
- WP-CLI must be installed on the server
- WordPress installations must be properly configured
- Sufficient permissions to modify WordPress files

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/wordpress.sh

# Run through the main optimizer
./optimize.sh --module wordpress
```

## Configuration
The module uses these default settings (configurable in the module file):
- Redis Database Starting Index: 0
- Redis Database Limit: 16

## Technical Notes
- Automatically detects WordPress installations using wp-config.php files
- Handles errors gracefully and continues with the next site if one fails
- Respects Redis database limits to prevent overutilization
- Provides detailed logging of the entire process
- Compatible with cPanel and other hosting environments
