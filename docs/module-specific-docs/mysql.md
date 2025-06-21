# MySQL Module

## Overview
The MySQL Module provides functions for optimizing MySQL/MariaDB database configuration based on server resources. It uses pre-defined templates for different server types to apply proven, optimal configurations.

## Features

### Template-Based MySQL Optimization
- Applies optimized MySQL configurations using server-specific templates
- Supports various server types with appropriate resource allocations:
  - VPS1 through VPS5 for virtual private servers
  - DSCPU1 through DSCPU5 for dedicated servers
  - Those are based on the Linode shared and dedicated servers listed here:
  https://www.linode.com/pricing/
- Automatically detects MySQL/MariaDB service type
- Handles service-specific requirements for different MySQL variants
- Safely removes problematic performance schema settings
- Uncomments specific recommended settings

### Database Configuration Management
- Creates backups of existing MySQL configuration
- Verifies configuration before and after application
- Includes rollback capability for failed configuration attempts
- Adds configuration metadata (server type, date) for future reference
- Restarts MySQL service to apply changes

## Requirements
- MySQL or MariaDB installed and managed by systemd
- Access to the MySQL configuration file (/etc/my.cnf)
- Root access to restart the database service
- MySQL template files must be available

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/mysql.sh

# Run through the main optimizer
./optimize.sh --module mysql
```

## Technical Notes
- Configuration templates are located in templates/mysql/
- Supports automatic server type detection in non-interactive mode
- Validates server type against supported types
- Performs safeguards to prevent known problematic settings
- Works with both MySQL and MariaDB services
- Verifies MySQL is running properly after configuration changes
