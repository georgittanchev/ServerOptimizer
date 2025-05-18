# cPanel Module

## Overview
The cPanel Module provides functions for optimizing cPanel settings and enhancing cPanel server performance through the installation of Engintron, an Nginx web server proxy  system for cPanel.

## Features

### cPanel Tweak Settings Optimization
- Disables resource-intensive and unnecessary services:
  - Analog, Awstats, Webalizer (statistics)
  - Mailman (mailing lists)
  - BoxTrapper (email filtering)
  - SpamAssassin (spam filtering)
- Prevents MySQL automatic configuration adjustments:
  - Disables max_allowed_packet auto-adjustment
  - Disables open_files_limit auto-adjustment
  - Disables InnoDB buffer pool size auto-adjustment
  We are doing that because we optimize MySQL manually in our MySQL module.
- Optimizes disk usage calculations that take RAM and CPU:
  - Excludes Mailman from disk usage
  - Excludes SQL databases from disk usage
- Modifies mail behavior settings

### Engintron Installation
- Checks for LiteSpeed before installation to prevent conflicts
- Downloads and installs the latest version of Engintron
- Configures Nginx with the server's primary IP address
- Updates AutoSSL cron job to reload Nginx after certificate renewal since there is a known issue when SSL is installed it is not being applied directly, thus EngineTron needs to be rebooted or cache cleared, this fixes that issue.
- Provides compatibility with cPanel's AutoSSL system

## Requirements
- cPanel/WHM server
- Root access
- WHM API access
- Compatible with cPanel on CentOS/RHEL systems

## Usage
This module can be called directly with specific subcommands or through the main optimization script:

```bash
# Run directly
./modules/cpanel.sh tweak     # Modify cPanel tweak settings
./modules/cpanel.sh engintron # Install and configure Engintron

# Run through the main optimizer
./optimize.sh --module cpanel
```

## Technical Notes
- Uses WHM API for direct modification of cPanel settings
- Creates backups of configuration files before making changes
- Automatically detects server IP for Engintron configuration
- Provides detailed logging and success/failure reporting
