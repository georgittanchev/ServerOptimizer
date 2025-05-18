#!/bin/bash
#
# Module: WordPress Optimization
# Description: Functions for configuring WordPress to use Redis
#
# This module contains functions for optimizing WordPress installations
# by configuring Redis caching integration.

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Default settings that can be overridden in config
REDIS_DATABASE=0
REDIS_DB_LIMIT=16

# Function to configure WordPress for Redis
configure_wordpress_redis() {
  print_section "Configuring WordPress for Redis"
  log_info "Starting WordPress Redis configuration process"
  
  # Check for WP-CLI
  if ! command -v wp &> /dev/null; then
    log_error "WordPress CLI not found. Please install it before running this function."
    print_error "WordPress CLI not found. Please install it before running this function."
    return 1
  fi

  # Find WordPress installations
  log_info "Searching for WordPress installations..."
  print_info "Searching for WordPress installations..."
  
  find /home -type f -name "wp-config.php" | while read -r wp_config; do
    # Skip plugin directories
    if [[ "$wp_config" == *"/plugins/"* ]]; then
      log_debug "Skipping plugin directory: $wp_config"
      continue
    fi

    # Check Redis database limit
    if [ "$REDIS_DATABASE" -ge "$REDIS_DB_LIMIT" ]; then
      log_warn "Redis database limit of $REDIS_DB_LIMIT reached. Skipping further WordPress Redis configuration."
      print_warning "Redis database limit of $REDIS_DB_LIMIT reached. Skipping further WordPress Redis configuration."
      break
    fi

    wp_path=$(dirname "$wp_config")
    log_info "Processing WordPress site at: $wp_path"
    print_info "Processing WordPress site at: $wp_path"
    
    # Check if WordPress is properly installed
    if ! wp core is-installed --allow-root --path="$wp_path" --quiet; then
      log_warn "WordPress not properly installed at $wp_path. Skipping..."
      print_warning "WordPress not properly installed at $wp_path. Skipping..."
      continue
    fi

    log_info "Configuring Redis for WordPress site: $wp_config"
    print_info "Configuring Redis for WordPress site: $wp_config"
    
    # Increase memory limit temporarily for this operation
    wp config set WP_MEMORY_LIMIT 256M --allow-root --path="$wp_path" 2>/dev/null || true
    
    # Try to install and activate Redis Cache plugin with error handling
    if ! wp plugin is-installed redis-cache --allow-root --path="$wp_path" 2>/dev/null; then
      log_info "Installing Redis Cache plugin at $wp_path"
      print_info "Installing Redis Cache plugin..."
      
      if ! wp plugin install redis-cache --allow-root --path="$wp_path" 2>/dev/null; then
        log_error "Failed to install Redis Cache plugin at $wp_path. Continuing with next site..."
        print_error "Failed to install Redis Cache plugin. Continuing with next site..."
        continue
      fi
    else
      log_info "Redis Cache plugin already installed at $wp_path"
    fi
    
    # Activate plugin with error handling
    log_info "Activating Redis Cache plugin..."
    wp plugin activate redis-cache --allow-root --path="$wp_path" 2>/dev/null || {
      log_error "Failed to activate Redis Cache plugin at $wp_path. Continuing with next site..."
      print_error "Failed to activate Redis Cache plugin. Continuing with next site..."
      continue
    }
    
    # Add Redis configuration to wp-config.php with error handling
    log_info "Setting Redis configuration in wp-config.php..."
    {
      wp config set WP_REDIS_HOST 127.0.0.1 --allow-root --path="$wp_path" 2>/dev/null
      wp config set WP_REDIS_PORT 6379 --allow-root --path="$wp_path" 2>/dev/null
      wp config set WP_REDIS_DATABASE "$REDIS_DATABASE" --allow-root --path="$wp_path" 2>/dev/null
    } || {
      log_error "Failed to set Redis configuration in wp-config.php at $wp_path. Continuing with next site..."
      print_error "Failed to set Redis configuration in wp-config.php. Continuing with next site..."
      continue
    }
    
    # Enable Redis with error handling
    log_info "Enabling Redis for WordPress..."
    wp redis enable --allow-root --path="$wp_path" 2>/dev/null || {
      if [[ $(wp redis status --allow-root --path="$wp_path" 2>&1) == *"already enabled"* ]]; then
        log_info "Redis already enabled for $wp_path. Continuing..."
        print_info "Redis already enabled for this site. Continuing..."
      } else {
        log_error "Failed to enable Redis at $wp_path. Continuing with next site..."
        print_error "Failed to enable Redis. Continuing with next site..."
        continue
      }
    }
    
    log_success "Successfully configured Redis for $wp_path"
    print_success "Successfully configured Redis for $wp_path"
    REDIS_DATABASE=$((REDIS_DATABASE + 1))
    
  done

  log_info "WordPress Redis configuration process complete."
  print_success "WordPress Redis configuration process complete."
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
  configure_wordpress_redis
fi
