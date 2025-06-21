#!/bin/bash
#
# Module: Security Optimization
# Description: Functions for enhancing server security
#
# This module contains functions for security hardening and
# implementing security best practices.

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

# Function to get active domains on this server
get_active_domains() {
    local active_domains=()
    local current_user=$(whoami)
    
    # Create temporary file for domain list
    tmp_domains_file=$(mktemp)
    
    if [ "$current_user" = 'root' ]; then
        # Process all users when running as root
        for user_home in /home/*; do
            if [ -d "$user_home" ]; then
                user=$(basename "$user_home")
                domain_data=$(uapi --user="$user" DomainInfo list_domains 2>/dev/null)
                if [ $? -eq 0 ]; then
                    # Process main domain
                    main_domain=$(echo "$domain_data" | grep 'main_domain:' | awk '{print $2}')
                    if [ ! -z "$main_domain" ]; then
                        echo "$main_domain" >> "$tmp_domains_file"
                    fi
                    
                    # Process addon domains
                    echo "$domain_data" | grep -A 1000 'addon_domains:' | grep '^ *- ' | sed 's/^ *- //' >> "$tmp_domains_file"
                    
                    # Process subdomains
                    echo "$domain_data" | grep -A 1000 'sub_domains:' | grep '^ *- ' | sed 's/^ *- //' >> "$tmp_domains_file"
                fi
            fi
        done
    else
        # Process domains for current user only
        domain_data=$(uapi DomainInfo list_domains 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Process main domain
            main_domain=$(echo "$domain_data" | grep 'main_domain:' | awk '{print $2}')
            if [ ! -z "$main_domain" ]; then
                echo "$main_domain" >> "$tmp_domains_file"
            fi
            
            # Process addon domains
            echo "$domain_data" | grep -A 1000 'addon_domains:' | grep '^ *- ' | sed 's/^ *- //' >> "$tmp_domains_file"
            
            # Process subdomains
            echo "$domain_data" | grep -A 1000 'sub_domains:' | grep '^ *- ' | sed 's/^ *- //' >> "$tmp_domains_file"
        fi
    fi
    
    # Add all domains to the array (no IP filtering)
    while IFS= read -r domain; do
        if [ ! -z "$domain" ]; then
            active_domains+=("$domain")
        fi
    done < "$tmp_domains_file"
    
    # Cleanup
    rm -f "$tmp_domains_file"
    
    # Return the array
    printf '%s\n' "${active_domains[@]}"
}

# Function to implement nginx bad bot blocker
implement_nginx_bad_bot_blocker() {
  print_section "Implementing Nginx Bad Bot Blocker"
  log_info "Starting Nginx Bad Bot Blocker implementation"
  
  # Check if nginx is installed and running
  if ! command -v nginx &> /dev/null; then
    log_error "Nginx is not installed on this system"
    print_error "Nginx is not installed on this system"
    return 1
  fi
  
  # Configuration
  local NGINX_CONF_DIR="/etc/nginx"
  local NGINX_BOTS_DIR="/etc/nginx/bots.d"
  local NGINX_CONF_D_DIR="/etc/nginx/conf.d"
  local COMMON_HTTP_CONF="/etc/nginx/common_http.conf"
  local INSTALL_SCRIPT_PATH="/usr/local/sbin/install-ngxblocker"
  
  # Check if Engintron is installed
  if [[ ! -f "$COMMON_HTTP_CONF" ]]; then
    log_error "Engintron not detected. This function is designed for Engintron/cPanel environments."
    print_error "Engintron not detected. This function is designed for Engintron/cPanel environments."
    return 1
  fi
  
  log_info "Engintron environment detected"
  print_info "Engintron environment detected"
  
  # Download installation script
  log_info "Downloading nginx-ultimate-bad-bot-blocker installation script..."
  print_info "Downloading nginx-ultimate-bad-bot-blocker installation script..."
  
  if wget -q https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O "$INSTALL_SCRIPT_PATH"; then
    chmod +x "$INSTALL_SCRIPT_PATH"
    log_success "Installation script downloaded and made executable"
    print_success "Installation script downloaded and made executable"
  else
    log_error "Failed to download installation script"
    print_error "Failed to download installation script"
    return 1
  fi
  
  # Install bot blocker files
  log_info "Installing bot blocker files..."
  print_info "Installing bot blocker files..."
  
  if "$INSTALL_SCRIPT_PATH" -x; then
    log_success "Bot blocker files installed successfully"
    print_success "Bot blocker files installed successfully"
  else
    log_error "Failed to install bot blocker files"
    print_error "Failed to install bot blocker files"
    return 1
  fi
  
  # Fix duplicate directives
  log_info "Fixing duplicate nginx directives..."
  print_info "Fixing duplicate nginx directives..."
  
  local botblocker_settings="$NGINX_CONF_D_DIR/botblocker-nginx-settings.conf"
  if [[ -f "$botblocker_settings" ]]; then
    sed -i 's/^server_names_hash_bucket_size/#server_names_hash_bucket_size/' "$botblocker_settings"
    sed -i 's/^server_names_hash_max_size/#server_names_hash_max_size/' "$botblocker_settings"
    log_success "Fixed duplicate directives in botblocker-nginx-settings.conf"
    print_success "Fixed duplicate directives in botblocker-nginx-settings.conf"
  fi
  
  # Update IP whitelist
  log_info "Updating IP whitelist with server IPs..."
  print_info "Updating IP whitelist with server IPs..."
  
  local whitelist_file="$NGINX_BOTS_DIR/whitelist-ips.conf"
  if [[ -f "$whitelist_file" ]]; then
    backup_file "$whitelist_file" || {
      log_warn "Failed to backup whitelist-ips.conf, continuing anyway"
    }
    
    # Get server IPs
    local server_ips=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1)
    
    if [[ -n "$server_ips" ]]; then
      local ip_section=""
      while IFS= read -r ip; do
        [[ -n "$ip" ]] && ip_section+="\t$ip\t\t0;\n"
      done <<< "$server_ips"
      
      # Insert server IPs after the "MY WHITELIST" section
      sed -i "/# MY WHITELIST/,/^$/c\\
# ------------\\
# MY WHITELIST\\
# ------------\\
\\
# Server IPs\\
$ip_section\\
" "$whitelist_file"
      
      log_success "IP whitelist updated with server IPs"
      print_success "IP whitelist updated with server IPs"
    fi
  fi
  
  # Update domain whitelist
  log_info "Updating domain whitelist..."
  print_info "Updating domain whitelist..."
  
  local domain_whitelist_file="$NGINX_BOTS_DIR/whitelist-domains.conf"
  if [[ -f "$domain_whitelist_file" ]]; then
    backup_file "$domain_whitelist_file" || {
      log_warn "Failed to backup whitelist-domains.conf, continuing anyway"
    }
    
    # Get active domains using the new function
    local domains=$(get_active_domains)
    
    if [[ -n "$domains" ]]; then
      local domain_section=""
      while IFS= read -r domain; do
        if [[ -n "$domain" ]]; then
          local escaped_domain=$(echo "$domain" | sed 's/\./\\./g' | sed 's/-/\\-/g')
          domain_section+="\t\"~*(?:\\b)$escaped_domain(?:\\b)\" \t\t\t\t\t\t0;\n"
        fi
      done <<< "$domains"
      
      # Insert server domains after the "MY WHITELIST" section
      sed -i "/# MY WHITELIST/,/^$/c\\
# ------------\\
# MY WHITELIST\\
# ------------\\
\\
# Server domains\\
$domain_section\\
" "$domain_whitelist_file"
      
      log_success "Domain whitelist updated with server domains"
      print_success "Domain whitelist updated with server domains"
    fi
  fi
  
  # Configure Engintron includes
  log_info "Configuring Engintron includes..."
  print_info "Configuring Engintron includes..."
  
  if grep -q "blockbots.conf" "$COMMON_HTTP_CONF"; then
    log_info "Bot blocker includes already present in common_http.conf"
    print_info "Bot blocker includes already present in common_http.conf"
  else
    backup_file "$COMMON_HTTP_CONF" || {
      log_warn "Failed to backup common_http.conf, continuing anyway"
    }
    
    # Add bot blocker includes after custom_rules include
    sed -i '/include custom_rules;/a\\n# Include bot blocker rules\ninclude /etc/nginx/bots.d/blockbots.conf;\ninclude /etc/nginx/bots.d/ddos.conf;' "$COMMON_HTTP_CONF"
    
    log_success "Added bot blocker includes to common_http.conf"
    print_success "Added bot blocker includes to common_http.conf"
  fi
  
  # Test nginx configuration
  log_info "Testing nginx configuration..."
  print_info "Testing nginx configuration..."
  
  if nginx -t 2>/dev/null; then
    log_success "Nginx configuration test passed"
    print_success "Nginx configuration test passed"
    
    # Reload nginx
    log_info "Reloading nginx..."
    print_info "Reloading nginx..."
    
    if nginx -s reload 2>/dev/null; then
      log_success "Nginx reloaded successfully"
      print_success "Nginx reloaded successfully"
    else
      log_error "Failed to reload nginx"
      print_error "Failed to reload nginx"
      return 1
    fi
  else
    log_error "Nginx configuration test failed"
    print_error "Nginx configuration test failed"
    nginx -t
    return 1
  fi
  
  log_success "Nginx Bad Bot Blocker implementation complete"
  print_success "Nginx Bad Bot Blocker implementation complete"
  return 0
}

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
  
  # Get active domains using the new function
  log_info "Fetching active domains"
  local domains_info=$(get_active_domains)
  
  if [ -z "$domains_info" ]; then
    log_warn "No domains found. Whitelist will not include specific domains."
    print_warning "No domains found. Whitelist will not include specific domains."
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

# Function to detect web server and implement appropriate bad bot blocker
implement_web_server_bad_bot_blocker() {
  print_section "Detecting Web Server and Implementing Bad Bot Blocker"
  log_info "Starting web server detection for bad bot blocker implementation"
  
  # Check if nginx is active
  if systemctl is-active --quiet nginx; then
    log_info "Nginx is active - implementing Nginx Bad Bot Blocker"
    print_info "Nginx is active - implementing Nginx Bad Bot Blocker"
    implement_nginx_bad_bot_blocker
    return $?
  # Check if Apache is active
  elif systemctl is-active --quiet httpd || systemctl is-active --quiet apache2; then
    log_info "Apache is active - implementing Apache Bad Bot Blocker"
    print_info "Apache is active - implementing Apache Bad Bot Blocker"
    implement_bad_bot_blocker
    return $?
  else
    log_warn "Neither nginx nor Apache appears to be active"
    print_warning "Neither nginx nor Apache appears to be active"
    
    # Check if nginx is installed
    if command -v nginx &> /dev/null; then
      log_info "Nginx is installed but not active - implementing Nginx Bad Bot Blocker anyway"
      print_info "Nginx is installed but not active - implementing Nginx Bad Bot Blocker anyway"
      implement_nginx_bad_bot_blocker
      return $?
    # Check if Apache is installed
    elif command -v httpd &> /dev/null || command -v apache2 &> /dev/null; then
      log_info "Apache is installed but not active - implementing Apache Bad Bot Blocker anyway"
      print_info "Apache is installed but not active - implementing Apache Bad Bot Blocker anyway"
      implement_bad_bot_blocker
      return $?
    else
      log_error "No web server (nginx or Apache) found on this system"
      print_error "No web server (nginx or Apache) found on this system"
      return 1
    fi
  fi
}

# Function to implement bad bot blocker (kept for backwards compatibility)
implement_bad_bot_blocker_legacy() {
  implement_web_server_bad_bot_blocker
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Source required libraries (in case this is being run standalone)
  if [ -z "$MODULE_LIB_DIR" ]; then
    MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MODULE_LIB_DIR="$(dirname "$MODULE_DIR")/lib"
    
    # Initialize logging
    init_logging "/var/log/server-optimizer.log" "INFO"
  fi
  
  # Run the function
  implement_bad_bot_blocker
fi
