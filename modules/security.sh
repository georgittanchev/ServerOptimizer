#!/bin/bash
#
# Module: Security Optimization
# Description: Functions for enhancing server security
#
# This module contains functions for implementing security enhancements
# such as bad bot blocking and other security measures.

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Function to implement bad bot blocker for Apache
implement_bad_bot_blocker() {
  print_section "Implementing Bad Bot Blocker"
  log_info "Starting Bad Bot Blocker implementation"
  
  # Ensure jq is installed
  if ! command -v jq &> /dev/null; then
    log_info "Installing jq for JSON processing..."
    print_info "Installing jq for JSON processing..."
    
    if ! yum install -y jq; then
      log_error "Failed to install jq. Cannot continue."
      print_error "Failed to install jq. Cannot continue."
      return 1
    fi
    
    log_success "jq installed successfully"
  fi
  
  # Define variables
  local APACHE_VERSION='2.4'
  local APACHE_CONF='/etc/apache2'
  local BLOCKER_URL="https://raw.githubusercontent.com/mitchellkrogza/apache-ultimate-bad-bot-blocker/master/Apache_${APACHE_VERSION}/custom.d"
  
  # Create custom.d directory if it doesn't exist
  log_info "Creating custom.d directory if it doesn't exist"
  if [ ! -d "${APACHE_CONF}/custom.d" ]; then
    if ! mkdir -p "${APACHE_CONF}/custom.d"; then
      log_error "Failed to create directory: ${APACHE_CONF}/custom.d"
      print_error "Failed to create directory: ${APACHE_CONF}/custom.d"
      return 1
    fi
    log_info "Created custom.d directory"
  fi
  
  # Download Bad Bot Blocker files
  log_info "Downloading Bad Bot Blocker files..."
  print_info "Downloading Bad Bot Blocker files..."
  
  local files=(
    "globalblacklist.conf"
    "whitelist-ips.conf"
    "whitelist-domains.conf"
    "blacklist-ips.conf"
    "bad-referrer-words.conf"
    "blacklist-user-agents.conf"
  )
  
  local download_errors=0
  for file in "${files[@]}"; do
    log_info "Downloading ${file}..."
    if ! wget "${BLOCKER_URL}/${file}" -O "${APACHE_CONF}/custom.d/${file}" -q; then
      log_error "Failed to download ${file}"
      print_error "Failed to download ${file}"
      ((download_errors++))
    fi
  done
  
  if [ $download_errors -gt 0 ]; then
    log_warn "${download_errors} file(s) failed to download"
    print_warning "${download_errors} file(s) failed to download"
  else
    log_success "Bad Bot Blocker files downloaded and installed"
    print_success "Bad Bot Blocker files downloaded and installed"
  fi
  
  # Add Cloudflare IP ranges and server IPs to whitelist
  log_info "Adding Cloudflare IP ranges and server IPs to whitelist"
  print_info "Adding Cloudflare IP ranges and server IPs to whitelist"
  
  # Backup existing whitelist
  backup_file "${APACHE_CONF}/custom.d/whitelist-ips.conf" || {
    log_warn "Failed to backup whitelist-ips.conf, continuing anyway"
  }
  
  # Generate updated whitelist with Cloudflare IPs
  {
    echo "# Cloudflare IP ranges"
    echo "Require ip 103.21.244.0/22"
    echo "Require ip 103.22.200.0/22"
    echo "Require ip 103.31.4.0/22"
    echo "Require ip 104.16.0.0/13"
    echo "Require ip 104.24.0.0/14"
    echo "Require ip 108.162.192.0/18"
    echo "Require ip 131.0.72.0/22"
    echo "Require ip 141.101.64.0/18"
    echo "Require ip 162.158.0.0/15"
    echo "Require ip 172.64.0.0/13"
    echo "Require ip 173.245.48.0/20"
    echo "Require ip 188.114.96.0/20"
    echo "Require ip 190.93.240.0/20"
    echo "Require ip 197.234.240.0/22"
    echo "Require ip 198.41.128.0/17"
    echo "Require ip 199.27.128.0/21"
    echo "Require ip 2400:cb00::/32"
    echo "Require ip 2606:4700::/32"
    echo "Require ip 2803:f800::/32"
    echo "Require ip 2405:b500::/32"
    echo "Require ip 2405:8100::/32"
    echo "Require ip 2c0f:f248::/32"
    echo "Require ip 2a06:98c0::/29"
    echo ""
    echo "# Server IPs"
    # Get all server IPs and add them to whitelist
    ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | while read -r ip; do
      echo "Require ip $ip"
    done
  } > "${APACHE_CONF}/custom.d/whitelist-ips.conf"
  
  log_success "Cloudflare IP ranges and server IPs added to whitelist"
  print_success "Cloudflare IP ranges and server IPs added to whitelist"
  
  # Add domains to whitelist
  log_info "Adding domains to whitelist"
  print_info "Adding domains to whitelist"
  
  # Backup existing domain whitelist
  backup_file "${APACHE_CONF}/custom.d/whitelist-domains.conf" || {
    log_warn "Failed to backup whitelist-domains.conf, continuing anyway"
  }
  
  # Get all domains from WHM API
  log_info "Fetching domains from WHM API"
  local domains_info
  if command -v whmapi1 &> /dev/null; then
    domains_info=$(whmapi1 --output=jsonpretty get_domain_info 2>/dev/null | jq -r '.data.domains[] | select(.domain_type == "main" or .domain_type == "addon") | .domain' 2>/dev/null)
    
    if [ -z "$domains_info" ]; then
      log_warn "No domains found or WHM API error. Whitelist will not include specific domains."
      print_warning "No domains found or WHM API error. Whitelist will not include specific domains."
    else
      # Generate domain whitelist
      {
        echo "# Whitelisted domains"
        echo "$domains_info" | while read -r domain; do
          if [ ! -z "$domain" ]; then
            echo "SetEnvIfNoCase Referer ~*$domain good_ref"
          fi
        done
      } > "${APACHE_CONF}/custom.d/whitelist-domains.conf"
      
      log_success "Domains added to whitelist"
      print_success "Domains added to whitelist"
    fi
  else
    log_warn "WHM API not available. Skipping domain whitelist generation."
    print_warning "WHM API not available. Skipping domain whitelist generation."
  fi
  
  # Create new configuration file with Directory parameter
  log_info "Creating Bad Bot Blocker main configuration file"
  print_info "Creating Bad Bot Blocker main configuration file"
  
  local NEW_CONF_FILE="/etc/apache2/conf.d/bad_bot_blocker.conf"
  
  # Backup existing config if it exists
  if [ -f "$NEW_CONF_FILE" ]; then
    backup_file "$NEW_CONF_FILE" || {
      log_warn "Failed to backup existing Bad Bot Blocker configuration, continuing anyway"
    }
  fi
  
  # Create the config file
  {
    echo "<Directory /home>"
    echo "    AllowOverride All"
    echo "    Options FollowSymLinks"
    echo "    Include ${APACHE_CONF}/custom.d/globalblacklist.conf"
    echo "</Directory>"
  } > "$NEW_CONF_FILE"
  
  # Set proper ownership and permissions
  chown root:root "$NEW_CONF_FILE"
  chmod 0600 "$NEW_CONF_FILE"
  
  log_success "Bad Bot Blocker main configuration file created"
  print_success "Bad Bot Blocker main configuration file created"
  
  # Restart Apache if it's running
  if systemctl is-active --quiet httpd; then
    log_info "Restarting Apache to apply configuration..."
    print_info "Restarting Apache to apply configuration..."
    
    if systemctl restart httpd; then
      log_success "Apache restarted successfully"
      print_success "Apache restarted successfully"
    else
      log_error "Failed to restart Apache. Please check Apache logs for errors."
      print_error "Failed to restart Apache. Please check Apache logs for errors."
      return 1
    fi
  else
    log_warn "Apache is not running. Please start it to apply the Bad Bot Blocker configuration."
    print_warning "Apache is not running. Please start it to apply the Bad Bot Blocker configuration."
  fi
  
  log_success "Bad Bot Blocker implementation complete"
  print_success "Bad Bot Blocker implementation complete"
  return 0
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Source required libraries (in case this is being run standalone)
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
  implement_bad_bot_blocker
fi
