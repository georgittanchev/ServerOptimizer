#!/bin/bash
#
# Module: Swap Management
# Description: Functions for managing swap space
#
# This module contains functions for calculating optimal swap size
# and managing swap space on the server.

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Function to calculate optimal swap size based on system RAM
calculate_swap_size() {
  local ram_gb=$1
  local ram_based_swap
  
  # If RAM size is not provided, calculate it from system
  if [ -z "$ram_gb" ]; then
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Detected system RAM: ${ram_gb}GB"
  fi
  
  log_info "Calculating optimal swap size for ${ram_gb}GB RAM"
  
  # Calculate RAM-based swap size following best practices
  if [ $ram_gb -le 2 ]; then
    # For small RAM (≤2GB), use 2x RAM
    ram_based_swap=$((ram_gb * 2))
    log_info "Using 2x RAM rule for small systems"
  elif [ $ram_gb -le 8 ]; then
    # For medium RAM (2-8GB), use 1x RAM
    ram_based_swap=$ram_gb
    log_info "Using 1x RAM rule for medium systems"
  elif [ $ram_gb -le 64 ]; then
    # For larger RAM (8-64GB), use 0.5x RAM
    ram_based_swap=$((ram_gb / 2))
    log_info "Using 0.5x RAM rule for larger systems"
  else
    # For very large RAM (>64GB), cap at 32GB
    ram_based_swap=32
    log_info "Using fixed 32GB cap for very large systems"
  fi

  # Get available disk space
  log_info "Analyzing available disk space..."
  local disk_info=$(df -BG / | awk 'NR==2 {print $2, $4}')
  local total_disk_gb=$(echo $disk_info | awk '{print $1}' | tr -d 'G')
  local avail_disk_gb=$(echo $disk_info | awk '{print $2}' | tr -d 'G')
  
  log_info "Total disk space: ${total_disk_gb}GB, Available: ${avail_disk_gb}GB"

  # Calculate minimum required free space (20GB or 10% of total disk, whichever is larger)
  local min_free_gb=$((total_disk_gb * 10 / 100))
  [ $min_free_gb -lt 20 ] && min_free_gb=20
  
  log_info "Minimum required free space: ${min_free_gb}GB"

  # Calculate maximum allowed swap based on available space
  # Use no more than 25% of available space, and ensure min_free_gb remains
  local max_swap_gb=$(( (avail_disk_gb - min_free_gb) * 25 / 100 ))
  
  # If max_swap_gb is negative or zero, we don't have enough free space
  if [ $max_swap_gb -le 0 ]; then
    log_error "Insufficient disk space for swap configuration"
    echo "0"
    return 1
  fi
  
  log_info "Maximum allowed swap based on disk space: ${max_swap_gb}GB"

  # Take the smaller of RAM-based and disk-based limits
  if [ $ram_based_swap -lt $max_swap_gb ]; then
    log_info "Final swap size (RAM-based): ${ram_based_swap}GB"
    echo "$ram_based_swap"
  else
    log_info "Final swap size (disk-based): ${max_swap_gb}GB"
    echo "$max_swap_gb"
  fi
  
  return 0
}

# Function to manage swap space
manage_swap() {
  print_section "Managing Swap Space"
  log_info "Starting swap space management"
  
  # Check if running on cPanel server
  if ! command -v /usr/local/cpanel/bin/create-swap &> /dev/null; then
    log_error "cPanel create-swap utility not found. This function requires a cPanel server."
    print_error "cPanel create-swap utility not found. This function requires a cPanel server."
    return 1
  fi
  
  # Get RAM in GB
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  print_info "Current RAM: ${ram_gb}GB"
  
  # Calculate new swap size
  log_info "Calculating optimal swap size..."
  local new_swap_size=$(calculate_swap_size $ram_gb)
  local exit_code=$?
  
  if [ $exit_code -ne 0 ] || [ "$new_swap_size" = "0" ]; then
    log_error "Insufficient disk space for swap file configuration"
    print_error "Error: Insufficient disk space for swap file configuration"
    return 1
  fi
  
  print_info "Calculated optimal swap size: ${new_swap_size}GB"
  
  # Get current swap info
  local current_swap_kb=$(free | awk '/^Swap:/{print $2}')
  local current_swap_gb=$((current_swap_kb / 1024 / 1024))
  
  if [ $current_swap_gb -eq $new_swap_size ]; then
    log_info "Current swap size (${current_swap_gb}GB) already matches the optimal size"
    print_info "Current swap size (${current_swap_gb}GB) already matches the optimal size"
    return 0
  fi
  
  log_info "Current swap size: ${current_swap_gb}GB, Target size: ${new_swap_size}GB"
  print_info "Current swap size: ${current_swap_gb}GB"
  
  # Confirm with user if not in non-interactive mode
  if [[ "$NON_INTERACTIVE" != "true" ]]; then
    if ! ask_yes_no "Proceed with creating ${new_swap_size}GB swap?"; then
      log_info "Swap creation cancelled by user"
      print_info "Swap creation cancelled"
      return 0
    fi
  else
    log_info "Running in non-interactive mode, proceeding with swap creation"
  fi
  
  log_info "Turning off swap..."
  print_info "Turning off swap..."
  swapoff -a
  
  # Comment out the swap line in /etc/fstab to prevent automatic activation
  log_info "Updating /etc/fstab..."
  
  # Backup fstab first
  backup_file "/etc/fstab" || {
    log_warn "Failed to backup /etc/fstab, continuing anyway"
  }
  
  # Comment out existing swap entries
  if grep -q "swap" /etc/fstab; then
    sed -i 's/^\/dev\/\([a-z0-9]\+\).*swap.*/#&/' /etc/fstab
    log_info "Commented out swap entries in /etc/fstab"
  else
    log_info "No swap entries found in /etc/fstab"
  fi
  
  # Create new swap file using cPanel utility
  log_info "Creating new swap file using cPanel utility..."
  print_info "Creating new ${new_swap_size}GB swap file..."
  
  if ! /usr/local/cpanel/bin/create-swap --size ${new_swap_size}G -v; then
    log_error "Failed to create swap file"
    print_error "Failed to create swap file"
    return 1
  fi
  
  # Verify the new swap
  local new_swap_kb=$(free | awk '/^Swap:/{print $2}')
  local new_swap_gb=$((new_swap_kb / 1024 / 1024))
  
  if [ $new_swap_gb -gt 0 ]; then
    log_success "Swap management completed successfully. New swap size: ${new_swap_gb}GB"
    print_success "Swap management completed. New swap size: ${new_swap_gb}GB"
  else
    log_error "Swap creation might have failed. No active swap detected."
    print_error "Swap creation might have failed. No active swap detected."
    return 1
  fi
  
  return 0
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Source required libraries (in case we're running standalone)
  if [ -z "$LIB_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
    source "$LIB_DIR/logging.sh"
    source "$LIB_DIR/utils.sh"
    source "$LIB_DIR/ui.sh"
    
    # Initialize logging
    init_logging "/var/log/server-optimizer.log" "INFO"
  fi
  
  # Run the function
  manage_swap
fi
