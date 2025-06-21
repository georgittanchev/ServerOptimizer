# Swap Module

## Overview
The Swap Module provides functions for calculating and managing optimal swap space on cPanel servers. It ensures servers have the appropriate amount of swap space based on RAM and available disk space.

## Features

### Optimal Swap Size Calculation
- Calculates appropriate swap size based on system RAM:
  - 2× RAM for systems with ≤2GB RAM
  - 1× RAM for systems with 2-8GB RAM
  - 0.5× RAM for systems with 8-64GB RAM
  - Fixed 32GB cap for systems with >64GB RAM
- Considers available disk space to ensure server stability
- Ensures a minimum of 20GB or 10% of disk remains free, whichever is larger
- Limits swap to 25% of available disk space after reserving minimum free space

### Swap Management
- Safely turns off existing swap space
- Updates /etc/fstab to prevent automatic activation of old swap
- Creates new swap file using cPanel's create-swap utility
- Verifies successful creation of new swap space
- Works in both interactive and non-interactive modes

## Requirements
- cPanel server with create-swap utility
- Root access to the server
- Sufficient disk space for swap creation

## Usage
This module can be called directly or as part of the main optimization script:

```bash
# Run directly
./modules/swap.sh

# Run through the main optimizer
./optimize.sh --module swap
```

## Technical Notes
- Creates backups of the /etc/fstab file before making changes
- Provides detailed logging of all operations
- Safely comments out existing swap entries in /etc/fstab
- Uses cPanel's create-swap utility to ensure compatibility
