#!/bin/bash
#
# Module: Apache Optimization
# Description: Functions for optimizing Apache web server
#
# This module contains functions for configuring Apache settings
# and optimizing its performance.

# Source required libraries without changing globals
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_LIB_DIR="$(dirname "$MODULE_DIR")/lib"

# Only source libraries if they haven't been loaded already
if [[ -z "$LOGGING_LOADED" ]]; then
  source "$MODULE_LIB_DIR/logging.sh"
  LOGGING_LOADED=true
fi

if [[ -z "$UTILS_LOADED" ]]; then
  source "$MODULE_LIB_DIR/utils.sh"
  UTILS_LOADED=true
fi

if [[ -z "$UI_LOADED" ]]; then
  source "$MODULE_LIB_DIR/ui.sh"
  UI_LOADED=true
fi

# Helper function to convert MB to KB for Apache limits
mb_to_kb() {
  local mb=$1
  echo $((mb * 1024))  # Convert to KB for Apache
}

# Function to switch Apache MPM from worker to event
switch_apache_mpm() {
  print_section "Switching Apache MPM from worker to event"
  log_info "Starting Apache MPM switch..."
  
  # Check if worker MPM is installed
  if rpm -q ea-apache24-mod_mpm_worker > /dev/null; then
    log_info "Removing worker MPM safely..."
    print_info "Removing worker MPM safely..."
    
    if ! rpm -e --nodeps ea-apache24-mod_mpm_worker; then
      log_error "Failed to remove worker MPM"
      print_error "Failed to remove worker MPM"
      return 1
    fi
  else
    log_info "Worker MPM not found, proceeding with event installation..."
    print_info "Worker MPM not found, proceeding with event installation..."
  fi

  # Install event MPM
  if ! rpm -q ea-apache24-mod_mpm_event > /dev/null; then
    log_info "Installing event MPM..."
    print_info "Installing event MPM..."
    
    if ! yum install -y ea-apache24-mod_mpm_event; then
      log_error "Failed to install event MPM"
      print_error "Failed to install event MPM"
      return 1
    fi
    
    # Verify installation
    if rpm -q ea-apache24-mod_mpm_event > /dev/null; then
      log_info "Event MPM installed successfully."
      print_success "Event MPM installed successfully."
      
      # Verify module is loaded
      if httpd -M 2>/dev/null | grep -q mpm_event_module; then
        log_info "Event MPM module is loaded correctly."
        print_success "Event MPM module is loaded correctly."
      else
        log_warn "Event MPM module installation successful but module not loaded."
        print_warning "Event MPM module installation successful but module not loaded."
      fi
    else
      log_error "Failed to install event MPM."
      print_error "Failed to install event MPM."
      return 1
    fi
  else
    log_info "Event MPM is already installed."
    print_info "Event MPM is already installed."
  fi

  # Restart Apache to apply changes
  log_info "Restarting Apache..."
  print_info "Restarting Apache..."
  
  if systemctl restart httpd; then
    log_info "Apache restarted successfully."
    print_success "Apache restarted successfully."
    
    # Verify Apache is running with event MPM
    if httpd -V 2>/dev/null | grep -q "Server MPM:.*event"; then
      log_info "Apache is now running with event MPM."
      print_success "Apache is now running with event MPM."
    else
      log_warn "Apache restarted but may not be using event MPM. Please check manually."
      print_warning "Apache restarted but may not be using event MPM. Please check manually."
    fi
  else
    log_error "Failed to restart Apache. Please check the logs."
    print_error "Failed to restart Apache. Please check the logs."
    return 1
  fi
  
  return 0
}

# Function to optimize Apache settings
optimize_apache_settings() {
  local EA4_CONF="/etc/cpanel/ea4/ea4.conf"
  
  print_section "Optimizing Apache Settings"
  log_info "Starting Apache optimization..."
  
  # Backup original configuration
  if [ -f "$EA4_CONF" ]; then
    if ! backup_file "$EA4_CONF"; then
      log_error "Failed to backup $EA4_CONF"
      print_error "Failed to backup $EA4_CONF"
      return 1
    fi
  else
    log_error "Error: ea4.conf not found at $EA4_CONF"
    print_error "Error: ea4.conf not found at $EA4_CONF"
    return 1
  fi

  # Read server type from user input or use existing value
  if [ -z "$SERVER_TYPE" ]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      SERVER_TYPE=$(detect_server_type)
      log_info "Auto-detected server type: $SERVER_TYPE"
    else
      echo "Enter the server type (VPS1-VPS8 or DSCPU1-DSCPU9):"
      read -r SERVER_TYPE
    fi
  fi

  log_info "Optimizing Apache for server type: $SERVER_TYPE"
  print_info "Optimizing Apache for server type: $SERVER_TYPE"

  # Define settings based on server type
  case "$SERVER_TYPE" in
    # VPS Configurations
    VPS1) # 2GB RAM, 1 CPU
      maxclients=25
      maxkeepalive=10
      maxrequests=200
      keepalive="On"
      serverlimit=30
      rlimit_cpu_soft=120
      rlimit_cpu_hard=180
      rlimit_mem_soft=$(mb_to_kb 1536)
      rlimit_mem_hard=$(mb_to_kb 1843)
      timeout=60
      ;;
    VPS2) # 4GB RAM, 2 CPUs
      maxclients=50
      maxkeepalive=50
      maxrequests=400
      keepalive="On"
      serverlimit=60
      rlimit_cpu_soft=180
      rlimit_cpu_hard=240
      rlimit_mem_soft=$(mb_to_kb 3072)
      rlimit_mem_hard=$(mb_to_kb 3686)
      timeout=60
      ;;
    VPS3) # 8GB RAM, 4 CPUs
      maxclients=75
      maxkeepalive=100
      maxrequests=800
      keepalive="On"
      serverlimit=90
      rlimit_cpu_soft=240
      rlimit_cpu_hard=300
      rlimit_mem_soft=$(mb_to_kb 6144)
      rlimit_mem_hard=$(mb_to_kb 7372)
      timeout=60
      ;;
    VPS4) # 16GB RAM, 6 CPUs
      maxclients=100
      maxkeepalive=150
      maxrequests=1600
      keepalive="On"
      serverlimit=120
      rlimit_cpu_soft=300
      rlimit_cpu_hard=360
      rlimit_mem_soft=$(mb_to_kb 12288)
      rlimit_mem_hard=$(mb_to_kb 14745)
      timeout=60
      ;;
    VPS5) # 32GB RAM, 8 CPUs
      maxclients=150
      maxkeepalive=200
      maxrequests=3200
      keepalive="On"
      serverlimit=180
      rlimit_cpu_soft=360
      rlimit_cpu_hard=420
      rlimit_mem_soft=$(mb_to_kb 24576)
      rlimit_mem_hard=$(mb_to_kb 29491)
      timeout=60
      ;;
    VPS6) # 64GB RAM, 16 CPUs
      maxclients=200
      maxkeepalive=250
      maxrequests=6400
      keepalive="On"
      serverlimit=240
      rlimit_cpu_soft=420
      rlimit_cpu_hard=480
      rlimit_mem_soft=$(mb_to_kb 49152)
      rlimit_mem_hard=$(mb_to_kb 58982)
      timeout=60
      ;;
    VPS7) # 96GB RAM, 20 CPUs
      maxclients=250
      maxkeepalive=300
      maxrequests=9600
      keepalive="On"
      serverlimit=300
      rlimit_cpu_soft=480
      rlimit_cpu_hard=540
      rlimit_mem_soft=$(mb_to_kb 73728)
      rlimit_mem_hard=$(mb_to_kb 88474)
      timeout=60
      ;;
    VPS8) # 128GB RAM, 24 CPUs
      maxclients=300
      maxkeepalive=350
      maxrequests=12800
      keepalive="On"
      serverlimit=360
      rlimit_cpu_soft=540
      rlimit_cpu_hard=600
      rlimit_mem_soft=$(mb_to_kb 98304)
      rlimit_mem_hard=$(mb_to_kb 117965)
      timeout=60
      ;;
    # Dedicated Server Configurations
    DSCPU1) # 4GB RAM, 2 CPUs
      maxclients=50
      maxkeepalive=100
      maxrequests=2000
      keepalive="On"
      serverlimit=60
      rlimit_cpu_soft=240
      rlimit_cpu_hard=360
      rlimit_mem_soft=$(mb_to_kb 3072)
      rlimit_mem_hard=$(mb_to_kb 3686)
      timeout=60
      ;;
    DSCPU2) # 8GB RAM, 4 CPUs
      maxclients=100
      maxkeepalive=150
      maxrequests=4000
      keepalive="On"
      serverlimit=120
      rlimit_cpu_soft=300
      rlimit_cpu_hard=420
      rlimit_mem_soft=$(mb_to_kb 6144)
      rlimit_mem_hard=$(mb_to_kb 7372)
      timeout=60
      ;;
    DSCPU3) # 16GB RAM, 8 CPUs
      maxclients=200
      maxkeepalive=200
      maxrequests=8000
      keepalive="On"
      serverlimit=240
      rlimit_cpu_soft=360
      rlimit_cpu_hard=480
      rlimit_mem_soft=$(mb_to_kb 12288)
      rlimit_mem_hard=$(mb_to_kb 14745)
      timeout=60
      ;;
    DSCPU4) # 32GB RAM, 16 CPUs
      maxclients=400
      maxkeepalive=250
      maxrequests=16000
      keepalive="On"
      serverlimit=480
      rlimit_cpu_soft=420
      rlimit_cpu_hard=540
      rlimit_mem_soft=$(mb_to_kb 24576)
      rlimit_mem_hard=$(mb_to_kb 29491)
      timeout=60
      ;;
    DSCPU5) # 64GB RAM, 32 CPUs
      maxclients=800
      maxkeepalive=300
      maxrequests=32000
      keepalive="On"
      serverlimit=960
      rlimit_cpu_soft=480
      rlimit_cpu_hard=600
      rlimit_mem_soft=$(mb_to_kb 49152)
      rlimit_mem_hard=$(mb_to_kb 58982)
      timeout=60
      ;;
    DSCPU6) # 96GB RAM, 48 CPUs
      maxclients=1200
      maxkeepalive=350
      maxrequests=48000
      keepalive="On"
      serverlimit=1440
      rlimit_cpu_soft=540
      rlimit_cpu_hard=660
      rlimit_mem_soft=$(mb_to_kb 73728)
      rlimit_mem_hard=$(mb_to_kb 88474)
      timeout=60
      ;;
    DSCPU7) # 128GB RAM, 50 CPUs
      maxclients=1500
      maxkeepalive=400
      maxrequests=50000
      keepalive="On"
      serverlimit=1800
      rlimit_cpu_soft=600
      rlimit_cpu_hard=720
      rlimit_mem_soft=$(mb_to_kb 98304)
      rlimit_mem_hard=$(mb_to_kb 117965)
      timeout=60
      ;;
    DSCPU8) # 256GB RAM, 56 CPUs
      maxclients=2000
      maxkeepalive=450
      maxrequests=56000
      keepalive="On"
      serverlimit=2400
      rlimit_cpu_soft=660
      rlimit_cpu_hard=780
      rlimit_mem_soft=$(mb_to_kb 196608)
      rlimit_mem_hard=$(mb_to_kb 235929)
      timeout=60
      ;;
    DSCPU9) # 512GB RAM, 64 CPUs
      maxclients=2500
      maxkeepalive=500
      maxrequests=64000
      keepalive="On"
      serverlimit=3000
      rlimit_cpu_soft=720
      rlimit_cpu_hard=840
      rlimit_mem_soft=$(mb_to_kb 393216)
      rlimit_mem_hard=$(mb_to_kb 471859)
      timeout=60
      ;;
    *)
      log_error "Invalid server type: $SERVER_TYPE"
      print_error "Invalid server type: $SERVER_TYPE"
      return 1
      ;;
  esac

  log_info "Updating Apache settings for $SERVER_TYPE..."
  print_info "Updating Apache settings for $SERVER_TYPE..."
  
  # Check if jq is installed, and install it if not
  if ! command -v jq &>/dev/null; then
    log_info "Installing jq for JSON processing..."
    if ! yum install -y jq; then
      log_error "Failed to install jq. Cannot update Apache configuration."
      print_error "Failed to install jq. Cannot update Apache configuration."
      return 1
    fi
  fi
  
  # Use jq to update only existing configuration parameters
  local temp_conf=$(mktemp)
  if ! jq --arg maxclients "$maxclients" \
     --arg maxkeepalive "$maxkeepalive" \
     --arg maxrequests "$maxrequests" \
     --arg keepalive "$keepalive" \
     --arg serverlimit "$serverlimit" \
     --arg timeout "$timeout" \
     --arg rlimit_cpu_soft "$rlimit_cpu_soft" \
     --arg rlimit_cpu_hard "$rlimit_cpu_hard" \
     --arg rlimit_mem_soft "$rlimit_mem_soft" \
     --arg rlimit_mem_hard "$rlimit_mem_hard" \
     '.maxclients = ($maxclients|tonumber) |
      .maxkeepaliverequests = ($maxkeepalive|tonumber) |
      .maxrequestsperchild = ($maxrequests|tonumber) |
      .keepalive = $keepalive |
      .serverlimit = ($serverlimit|tonumber) |
      .timeout = ($timeout|tonumber) |
      .rlimit_cpu_soft = ($rlimit_cpu_soft|tonumber) |
      .rlimit_cpu_hard = ($rlimit_cpu_hard|tonumber) |
      .rlimit_mem_soft = ($rlimit_mem_soft|tonumber) |
      .rlimit_mem_hard = ($rlimit_mem_hard|tonumber)' \
      "$EA4_CONF" > "$temp_conf"; then
    log_error "Failed to update Apache configuration using jq."
    print_error "Failed to update Apache configuration using jq."
    rm -f "$temp_conf"
    return 1
  fi

  # Apply the new configuration
  mv "$temp_conf" "$EA4_CONF"
  chmod 644 "$EA4_CONF"
  
  log_info "Apache configuration updated successfully."
  print_success "Apache configuration updated successfully."
  
  # Display the new configuration
  log_info "New Apache configuration values:"
  log_info "MaxClients: $maxclients"
  log_info "MaxKeepAliveRequests: $maxkeepalive"
  log_info "MaxRequestsPerChild: $maxrequests"
  log_info "KeepAlive: $keepalive"
  log_info "ServerLimit: $serverlimit"
  log_info "Timeout: $timeout"
  log_info "CPU Soft Limit: $rlimit_cpu_soft"
  log_info "CPU Hard Limit: $rlimit_cpu_hard"
  log_info "Memory Soft Limit (KB): $rlimit_mem_soft"
  log_info "Memory Hard Limit (KB): $rlimit_mem_hard"
  
  print_info "New Apache configuration values:"
  print_info "MaxClients: $maxclients"
  print_info "MaxKeepAliveRequests: $maxkeepalive"
  print_info "MaxRequestsPerChild: $maxrequests"
  print_info "KeepAlive: $keepalive"
  print_info "ServerLimit: $serverlimit"
  print_info "Timeout: $timeout"
  
  # Restart Apache if it's running
  if systemctl is-active --quiet httpd; then
    log_info "Restarting Apache to apply changes..."
    print_info "Restarting Apache to apply changes..."
    
    if systemctl restart httpd; then
      log_info "Apache restarted successfully."
      print_success "Apache restarted successfully."
    else
      log_error "Failed to restart Apache. Please check the configuration and restart manually."
      print_error "Failed to restart Apache. Please check the configuration and restart manually."
      return 1
    fi
  else
    log_warn "Apache is not running. Please start it manually to apply changes."
    print_warning "Apache is not running. Please start it manually to apply changes."
  fi
  
  log_info "Apache optimization completed successfully."
  print_success "Apache optimization completed successfully."
  return 0
}

# If the script is executed directly, run the main functions
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Run the functions
  switch_apache_mpm
  optimize_apache_settings
fi
