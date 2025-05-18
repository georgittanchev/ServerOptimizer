#!/bin/bash
#
# Module: MySQL Optimization
# Description: Functions for optimizing MySQL/MariaDB database
#
# This module contains functions for configuring MySQL/MariaDB
# for optimal performance based on server resources.

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

# Path to MySQL configuration templates
TEMPLATE_DIR="$(dirname "$MODULE_DIR")/templates/mysql"

# Supported server types
SUPPORTED_SERVER_TYPES=("VPS1" "VPS2" "VPS3" "VPS4" "VPS5" "DSCPU1" "DSCPU2" "DSCPU3" "DSCPU4" "DSCPU5")

# Get template path for a server type
get_template_path() {
  local server_type=$1
  echo "${TEMPLATE_DIR}/${server_type}.cnf"
}

# Function to configure MySQL
configure_mysql() {
  print_section "Optimizing MySQL/MariaDB"
  log_info "Starting MySQL optimization"
  
  # Ensure template directory exists
  if [ ! -d "$TEMPLATE_DIR" ]; then
    log_error "MySQL template directory not found: $TEMPLATE_DIR"
    print_error "MySQL template directory not found. Run install.sh first."
    return 1
  fi
  
  # Check if MySQL/MariaDB is installed
  if ! systemctl is-enabled --quiet mysqld && ! systemctl is-enabled --quiet mariadb; then
    log_error "MySQL/MariaDB is not installed or not managed by systemd"
    print_error "MySQL/MariaDB is not installed or not managed by systemd"
    return 1
  fi
  
  # Determine which service is in use
  local mysql_service
  if systemctl is-enabled --quiet mysqld; then
    mysql_service="mysqld"
  else
    mysql_service="mariadb"
  fi
  
  log_info "Detected MySQL service: $mysql_service"
  
  # Prompt for server type if not already set
  if [ -z "$SERVER_TYPE" ]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      SERVER_TYPE=$(detect_server_type)
      log_info "Auto-detected server type: $SERVER_TYPE"
    else
      echo "Enter the server type (VPS1, VPS2, VPS3, VPS4, VPS5, DSCPU1, DSCPU2, DSCPU3, DSCPU4, DSCPU5):"
      read -r SERVER_TYPE
    fi
  fi
  
  # Validate server type
  local valid_type=false
  for type in "${SUPPORTED_SERVER_TYPES[@]}"; do
    if [ "$type" = "$SERVER_TYPE" ]; then
      valid_type=true
      break
    fi
  done
  
  if [ "$valid_type" = false ]; then
    log_error "Invalid server type: $SERVER_TYPE"
    print_error "Invalid server type: $SERVER_TYPE. Valid options are: ${SUPPORTED_SERVER_TYPES[*]}"
    return 1
  fi

  # Get template path for selected server type
  local template_path=$(get_template_path "$SERVER_TYPE")
  
  # Verify template exists
  if [ ! -f "$template_path" ]; then
    log_error "Template file not found: $template_path"
    print_error "MySQL template for $SERVER_TYPE not found. Run templates/mysql/download_templates.sh first."
    return 1
  fi
  
  log_info "Configuring MySQL for $SERVER_TYPE using template: $template_path"
  print_info "Configuring MySQL for $SERVER_TYPE using template: $template_path"
  
  # Backup existing configuration
  backup_file "/etc/my.cnf" || {
    log_error "Failed to backup /etc/my.cnf"
    print_error "Failed to backup /etc/my.cnf"
    return 1
  }
  
  # Copy template to my.cnf
  log_info "Applying MySQL configuration template..."
  if ! cp "$template_path" /etc/my.cnf; then
    log_error "Failed to apply MySQL configuration template"
    print_error "Failed to apply MySQL configuration template"
    return 1
  fi
  
  # Add server type comment to configuration
  sed -i "1i # Server Type: $SERVER_TYPE - Configuration applied by Server Optimizer on $(date)" /etc/my.cnf
  
  # Remove specific performance schema lines that might cause issues
  log_info "Removing specific performance schema settings..."
  sed -i '/performance_schema = on/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-statements-history-long = ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-statements-history = ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-statements-current = ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-stages-current=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-stages-history=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-stages-history-long=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-transactions-current=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-transactions-history=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-transactions-history-long=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-waits-current=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-waits-history=ON/d' /etc/my.cnf
  sed -i '/performance-schema-consumer-events-waits-history-long=ON/d' /etc/my.cnf
  sed -i '/performance-schema-instrument='"'"'%=ON'"'"'/d' /etc/my.cnf
  sed -i '/max-digest-length=2048/d' /etc/my.cnf
  sed -i '/performance-schema-max-digest-length=2048/d' /etc/my.cnf

  # Uncomment specific lines
  log_info "Uncommenting specific settings..."
  sed -i 's/^#\(sql_mode[[:space:]]*=[[:space:]]*""\)/\1/' /etc/my.cnf
  sed -i 's/^#default_authentication_plugin/default_authentication_plugin/' /etc/my.cnf

  # Verify configuration
  log_info "Verifying MySQL configuration..."
  if [ ! -f "/etc/my.cnf" ] || [ ! -s "/etc/my.cnf" ]; then
    log_error "MySQL configuration is missing or empty"
    print_error "MySQL configuration is missing or empty"
    return 1
  fi
  
  # Restart MySQL
  log_info "Restarting MySQL service..."
  print_info "Restarting MySQL service..."
  
  if ! systemctl restart $mysql_service; then
    log_error "Failed to restart MySQL service. Please check the configuration."
    print_error "Failed to restart MySQL service. Please check the configuration."
    
    # Try to restore backup
    log_warn "Attempting to restore original configuration..."
    if cp -f "/etc/my.cnf.bak."* "/etc/my.cnf" 2>/dev/null; then
      log_info "Original configuration restored"
      print_info "Original configuration restored"
      
      if systemctl restart $mysql_service; then
        log_info "MySQL service restarted with original configuration"
        print_success "MySQL service restarted with original configuration"
      else
        log_error "Failed to restart MySQL service with original configuration"
        print_error "Failed to restart MySQL service with original configuration"
      fi
    else
      log_error "Failed to restore original configuration"
      print_error "Failed to restore original configuration"
    fi
    
    return 1
  else
    log_info "MySQL service restarted successfully"
    print_success "MySQL service restarted successfully"
  fi
  
  # Verify MySQL is running
  if systemctl is-active --quiet $mysql_service; then
    log_info "MySQL is running with new configuration"
    print_success "MySQL is now optimized for $SERVER_TYPE"
    
    # Get MySQL version
    local mysql_version
    mysql_version=$(mysql --version 2>/dev/null | head -n 1)
    log_info "MySQL version: $mysql_version"
    print_info "MySQL version: $mysql_version"
    
    return 0
  else
    log_error "MySQL failed to start after configuration change"
    print_error "MySQL failed to start after configuration change"
    return 1
  fi
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Run the function
  configure_mysql
fi
