#!/bin/bash
#
# Module: Imunify360 Optimization
# Description: Functions for optimizing Imunify360 settings
#
# This module contains functions for optimizing Imunify360
# for better performance and security.

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

# Function to check if Imunify360 is installed
is_imunify_installed() {
  if command -v imunify360-agent &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to optimize Imunify360 settings
optimize_imunify360() {
  print_section "Optimizing Imunify360"
  log_info "Starting Imunify360 optimization"
  
  # Check if Imunify360 is installed
  if ! is_imunify_installed; then
    log_error "Imunify360 is not installed. Skipping optimization."
    print_error "Imunify360 is not installed. Skipping optimization."
    return 1
  fi
  
  print_info "Optimizing Imunify360 settings..."
  
  # Array of configuration changes to apply
  local settings=(
    # Set MALWARE_SCAN_INTENSITY for IO and CPU to lowest values
    '{"MALWARE_SCAN_INTENSITY": {"io": 1}}'
    '{"MALWARE_SCAN_INTENSITY": {"cpu": 1}}'
    
    # Enable automatic malicious file restore from backup
    '{"MALWARE_SCANNING": {"try_restore_from_backup_first": true}}'
    
    # Disable CAPTCHA DOS protection (can interfere with some services)
    '{"CAPTCHA_DOS": {"enabled": false}}'
    
    # Disable WebShield known proxies support
    '{"WEBSHIELD": {"known_proxies_support": false}}'
    
    # Disable WebShield (often conflicts with other proxies like Engintron)
    '{"WEBSHIELD": {"enable": false}}'
    
    # Disable ModSecurity block by severity
    '{"MOD_SEC_BLOCK_BY_SEVERITY": {"enable": false}}'
  )
  
  # Counter for successful and failed operations
  local success_count=0
  local failure_count=0
  
  # Apply each setting
  for setting in "${settings[@]}"; do
    # Extract the main key for logging
    local main_key=$(echo "$setting" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    local sub_key=$(echo "$setting" | grep -o '"[^"]*"' | head -2 | tail -1 | tr -d '"')
    
    log_info "Setting $main_key.$sub_key"
    print_info "Configuring $main_key.$sub_key"
    
    # Apply the setting using imunify360-agent
    if imunify360-agent config update "$setting"; then
      log_success "Successfully updated $main_key"
      ((success_count++))
    else
      log_error "Failed to update $main_key"
      print_error "Failed to update $main_key"
      ((failure_count++))
    fi
  done
  
  # Display summary
  if [ $failure_count -eq 0 ]; then
    print_success "All Imunify360 settings updated successfully"
  else
    print_warning "$failure_count settings failed to update"
  fi
  
  # Restart Imunify360
  log_info "Restarting Imunify360 to apply changes..."
  print_info "Restarting Imunify360 to apply changes..."
  
  if systemctl restart imunify360; then
    log_success "Imunify360 restarted successfully"
    print_success "Imunify360 restarted successfully"
  else
    log_error "Failed to restart Imunify360. Please restart it manually."
    print_error "Failed to restart Imunify360. Please restart it manually."
    ((failure_count++))
  fi
  
  if [ $failure_count -eq 0 ]; then
    log_success "Imunify360 optimization completed successfully"
    print_success "Imunify360 optimization completed successfully"
    return 0
  else
    log_warn "Imunify360 optimization completed with $failure_count errors"
    print_warning "Imunify360 optimization completed with $failure_count errors"
    return 1
  fi
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Source required libraries (in case we're running standalone)
  if [ -z "$MODULE_LIB_DIR" ]; then
    MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MODULE_LIB_DIR="$(dirname "$MODULE_DIR")/lib"
    source "$MODULE_LIB_DIR/logging.sh"
    source "$MODULE_LIB_DIR/utils.sh"
    source "$MODULE_LIB_DIR/ui.sh"
    
    # Initialize logging
    init_logging "/var/log/server-optimizer.log" "INFO"
  fi
  
  # Run the function
  optimize_imunify360
fi
