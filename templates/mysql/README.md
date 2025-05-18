# MySQL Configuration Templates

This directory contains pre-configured MySQL configuration files for different server types.

## Server Types

The server types are based on Linode's pricing tiers as defined at [Linode Pricing](https://www.linode.com/pricing/):

### VPS (Shared CPU Plans)
- VPS1: Equivalent to Linode 2 GB ($12/mo, 2 GB RAM, 1 vCPU, 50 GB Storage, 2 TB Transfer)
- VPS2: Equivalent to Linode 4 GB
- VPS3: Equivalent to Linode 8 GB
- VPS4: Equivalent to Linode 16 GB
- VPS5: Equivalent to Linode 32 GB

### DSCPU (Dedicated CPU Plans)
- DSCPU1: Equivalent to Dedicated 4 GB ($36/mo, 4 GB RAM, 2 vCPUs, 80 GB Storage, 4 TB Transfer)
- DSCPU2: Equivalent to Dedicated 8 GB
- DSCPU3: Equivalent to Dedicated 16 GB
- DSCPU4: Equivalent to Dedicated 32 GB
- DSCPU5: Equivalent to Dedicated 64 GB

## Usage

These templates are used by the MySQL optimization module. If you want to update these templates:

1. Edit the files directly
2. Run `download_templates.sh` to fetch fresh versions from the source

## File Naming Convention

Files are named according to the server type: `[SERVER_TYPE].cnf`
