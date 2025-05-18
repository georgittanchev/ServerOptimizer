#!/bin/bash
#
# Module: cPanel Optimization
# Description: Functions for optimizing cPanel settings
#
# This module contains functions for optimizing cPanel-specific settings
# and installing cPanel enhancements like Engintron.

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Function to modify cPanel tweak settings
direct_modify_cpanel_tweak_settings() {
  print_section "Modifying cPanel Tweak Settings"
  log_info "Starting direct modification of cPanel tweak settings via WHM API"
  
  # Check if running on a cPanel server
  if ! command -v whmapi1 &>/dev/null; then
    log_error "WHM API not found. This function requires a cPanel server."
    print_error "WHM API not found. This function requires a cPanel server."
    return 1
  fi

  # Define the settings to modify
  local settings=(
    "skipanalog 1"
    "skipawstats 1"
    "skipwebalizer 1"
    "skipmailman 1"
    "mycnf_auto_adjust_maxallowedpacket 0"
    "mycnf_auto_adjust_openfiles_limit 0"
    "mycnf_auto_adjust_innodb_buffer_pool_size 0"
    "disk_usage_include_mailman 0"
    "smtpmailgidonly 0"
    "disk_usage_include_sqldbs 0"
    "skipboxtrapper 1"
    "skipspamassassin 1"
  )

  local success_count=0
  local failure_count=0
  
  # Apply each setting
  for setting in "${settings[@]}"; do
    key=${setting%% *}
    value=${setting#* }
    
    log_info "Setting $key to $value"
    print_info "Setting $key to $value"
    
    # Use WHM API to modify the setting
    local result
    result=$(whmapi1 set_tweaksetting key="$key" value="$value" --output=json)
    
    # Check if the API call was successful
    if [[ "$(echo "$result" | grep -o '"result": *[0-9]*' | grep -o '[0-9]*')" == "1" ]]; then
      log_success "Successfully set $key to $value"
      print_success "Successfully set $key to $value"
      ((success_count++))
    else
      local reason
      reason=$(echo "$result" | grep -o '"reason": *"[^"]*"' | cut -d'"' -f4)
      log_error "Failed to set $key to $value. Reason: $reason"
      print_error "Failed to set $key to $value. Reason: $reason"
      ((failure_count++))
    fi
  done

  # Summarize results
  log_info "cPanel tweak settings modification complete"
  print_info "cPanel tweak settings modification complete"
  print_info "Successfully modified $success_count settings"
  
  if [[ $failure_count -gt 0 ]]; then
    print_warning "Failed to modify $failure_count settings"
  fi
  
  return 0
}

# Function to install Engintron
install_engintron() {
  print_section "Installing Engintron"
  log_info "Starting Engintron installation process"
  
  # Check if LiteSpeed is already installed
  if systemctl is-active --quiet lsws; then
    log_warn "LiteSpeed Web Server is already installed. Skipping Engintron installation."
    print_warning "LiteSpeed Web Server is already installed. Skipping Engintron installation."
    return 0
  fi

  log_info "Installing Engintron..."
  print_info "Installing Engintron..."
  
  # Download the installer
  if ! wget https://raw.githubusercontent.com/engintron/engintron/master/engintron.sh -O /root/engintron.sh; then
    log_error "Failed to download Engintron installer"
    print_error "Failed to download Engintron installer"
    return 1
  fi
  
  # Make it executable
  chmod +x /root/engintron.sh
  
  # Run the installer
  log_info "Running Engintron installer..."
  if ! bash /root/engintron.sh install; then
    log_error "Engintron installation failed"
    print_error "Engintron installation failed"
    return 1
  fi
  
  # Configure Nginx with server IP
  log_info "Configuring Nginx with server IP..."
  print_info "Configuring Nginx with server IP..."
  
  # Get the server's primary IP address
  local server_ip
  server_ip=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  log_info "Server IP detected: $server_ip"
  print_info "Server IP detected: $server_ip"
  
  # Update or add the PROXY_DOMAIN_OR_IP setting
  local custom_rules_file="/etc/nginx/custom_rules"
  if [ -f "$custom_rules_file" ]; then
    # Backup the file
    backup_file "$custom_rules_file" || log_warn "Failed to backup custom_rules file"
    
    # Check if the setting already exists
    if grep -q "set \$PROXY_DOMAIN_OR_IP" "$custom_rules_file"; then
      # Update existing setting
      log_info "Updating existing PROXY_DOMAIN_OR_IP setting..."
      sed -i "s|set \$PROXY_DOMAIN_OR_IP.*|set \$PROXY_DOMAIN_OR_IP \"$server_ip\"; # Use your cPanel's shared IP address here|" "$custom_rules_file"
    else
      # Add new setting
      log_info "Adding PROXY_DOMAIN_OR_IP setting..."
      echo "set \$PROXY_DOMAIN_OR_IP \"$server_ip\"; # Use your cPanel's shared IP address here" >> "$custom_rules_file"
    fi
  else
    log_warn "Custom rules file not found: $custom_rules_file. Unable to update PROXY_DOMAIN_OR_IP setting."
    print_warning "Custom rules file not found. Unable to update PROXY_DOMAIN_OR_IP setting."
  fi

  # Reload Engintron
  log_info "Reloading Engintron configuration..."
  if [ -f "/opt/engintron/engintron.sh" ]; then
    /opt/engintron/engintron.sh reload
  else
    log_warn "Engintron script not found at expected location. Unable to reload configuration."
    print_warning "Engintron script not found at expected location. Unable to reload configuration."
  fi

  # Modify AutoSSL cron job to reload Nginx after certificate renewal
  log_info "Modifying AutoSSL cron job..."
  print_info "Modifying AutoSSL cron job to reload Nginx after certificate renewal..."
  
  local cron_file="/etc/cron.d/cpanel_autossl"
  if [ -f "$cron_file" ]; then
    # Backup the file
    backup_file "$cron_file" || log_warn "Failed to backup AutoSSL cron file"
    
    # Update the cron job
    if grep -q "/usr/local/cpanel/bin/autossl_check --all" "$cron_file"; then
      sed -i 's#/usr/local/cpanel/bin/autossl_check --all#/usr/local/cpanel/bin/autossl_check --all \&\& /usr/sbin/nginx -s reload#' "$cron_file"
      log_success "AutoSSL cron job updated successfully"
      print_success "AutoSSL cron job updated successfully"
    else
      log_warn "AutoSSL cron job pattern not found. Unable to modify."
      print_warning "AutoSSL cron job pattern not found. Unable to modify."
    fi
  else
    log_warn "AutoSSL cron file not found: $cron_file. Unable to modify."
    print_warning "AutoSSL cron file not found. Unable to modify."
  fi

  log_success "Engintron installation and configuration complete"
  print_success "Engintron installation and configuration complete"
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
  
  # Run the functions
  if [[ "$1" == "tweak" ]]; then
    direct_modify_cpanel_tweak_settings
  elif [[ "$1" == "engintron" ]]; then
    install_engintron
  else
    echo "Usage: $0 [tweak|engintron]"
    echo "  tweak     - Modify cPanel tweak settings"
    echo "  engintron - Install and configure Engintron"
  fi
fi
