#!/bin/bash
#
# Module: Redis Installation and Configuration
# Description: Functions for installing and configuring Redis
#
# This module contains functions for installing and optimizing Redis
# for caching and performance improvement.

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

# Default settings that can be overridden in config
REDIS_DATABASE=0
REDIS_DB_LIMIT=16

# Calculate optimal Redis memory allocation based on server resources
calculate_redis_memory() {
  local server_type=$1
  local total_ram_mb
  
  print_info "Calculating optimal Redis memory allocation..."
  log_info "Calculating Redis memory for server type: $server_type"
  
  # Get total system memory in MB
  total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  
  # Convert to GB for easier calculation
  local total_ram_gb=$((total_ram_mb / 1024))
  log_info "Total system RAM: ${total_ram_gb}GB (${total_ram_mb}MB)"
  
  # Get MySQL memory usage (approximate from config)
  local mysql_memory_mb=0
  if [ -f "/etc/my.cnf" ]; then
    local innodb_buffer=$(grep innodb_buffer_pool_size /etc/my.cnf | grep -oE '[0-9]+[MGK]' | head -1)
    if [ ! -z "$innodb_buffer" ]; then
      case ${innodb_buffer: -1} in
        G) mysql_memory_mb=$((${innodb_buffer::-1} * 1024)) ;;
        M) mysql_memory_mb=${innodb_buffer::-1} ;;
        K) mysql_memory_mb=$((${innodb_buffer::-1} / 1024)) ;;
      esac
      log_info "Detected MySQL memory allocation: ${mysql_memory_mb}MB"
    fi
  fi
  
  # Calculate available memory after MySQL
  local available_ram_mb=$((total_ram_mb - mysql_memory_mb))
  log_info "Available RAM after MySQL: ${available_ram_mb}MB"
  
  # Calculate Redis memory based on server type and available RAM
  local redis_memory_mb
  case "$server_type" in
    VPS1|DSCPU1)  # 2-4GB RAM
      redis_memory_mb=$((available_ram_mb * 15 / 100)) # 15% of available RAM
      ;;
    VPS2|DSCPU2)  # 4-8GB RAM
      redis_memory_mb=$((available_ram_mb * 20 / 100)) # 20% of available RAM
      ;;
    VPS3|DSCPU3)  # 8-16GB RAM
      redis_memory_mb=$((available_ram_mb * 25 / 100)) # 25% of available RAM
      ;;
    VPS4|DSCPU4)  # 16-32GB RAM
      redis_memory_mb=$((available_ram_mb * 30 / 100)) # 30% of available RAM
      ;;
    *)  # Larger servers
      redis_memory_mb=$((available_ram_mb * 35 / 100)) # 35% of available RAM
      ;;
  esac
  
  # Set minimum and maximum limits
  [ $redis_memory_mb -lt 256 ] && redis_memory_mb=256  # Minimum 256MB
  [ $redis_memory_mb -gt 16384 ] && redis_memory_mb=16384  # Maximum 16GB
  
  log_info "Calculated Redis memory allocation: ${redis_memory_mb}MB"
  print_success "Calculated Redis memory: ${redis_memory_mb}MB"
  
  echo "${redis_memory_mb}mb"
}

# Function to install Remi repository
install_remi_repo() {
  local release=$1
  local repo_url

  log_info "Installing Remi repository for RHEL/CentOS release $release"
  print_info "Installing Remi repository..."

  case "$release" in
    9) repo_url="https://rpms.remirepo.net/enterprise/remi-release-9.rpm" ;;
    8) repo_url="https://rpms.remirepo.net/enterprise/remi-release-8.rpm" ;;
    7) repo_url="https://rpms.remirepo.net/enterprise/remi-release-7.rpm" ;;
    *) repo_url="https://rpms.remirepo.net/enterprise/remi-release-6.rpm" ;;
  esac

  if ! yum -y install "$repo_url"; then
    log_error "Failed to install Remi repository from $repo_url"
    print_error "Failed to install Remi repository"
    return 1
  fi
  
  # Clean and update yum cache
  log_info "Cleaning and updating yum cache"
  if ! yum clean all && yum -y update; then
    log_warn "Warning: Could not fully clean/update yum cache"
    print_warning "Warning: Could not fully clean/update yum cache"
    # Not a fatal error, continue
  fi
  
  log_info "Remi repository installed successfully"
  print_success "Remi repository installed successfully"
  return 0
}

# Function to install and configure Redis
install_configure_redis() {
  local server_type=$1
   
  print_section "Installing and Configuring Redis"
  log_info "Starting Redis installation and configuration"
  
  # Get RHEL/CentOS release number
  local release
  if [ -z "$RELEASE" ]; then
    release=$(rpm -q --qf %{version} $(rpm -q --whatprovides redhat-release) | cut -c 1)
    if [ -z "$release" ]; then
      log_error "Could not determine OS release version"
      print_error "Could not determine OS release version"
      return 1
    fi
    log_info "Detected OS release: $release"
  else
    release=$RELEASE
    log_info "Using provided OS release: $release"
  fi
  
  # If server_type is not provided, try to get it from a previous MySQL configuration
  if [ -z "$server_type" ]; then
    log_info "Server type not provided, checking MySQL configuration..."
    print_info "Server type not provided, checking MySQL configuration..."
    
    if [ -f "/etc/my.cnf" ]; then
      server_type=$(grep "# Server Type:" /etc/my.cnf | cut -d: -f2 | tr -d ' ' || echo "")
      if [ ! -z "$server_type" ]; then
        log_info "Detected server type from MySQL config: $server_type"
        print_info "Detected server type from MySQL config: $server_type"
      fi
    fi
       
    # If still not found, prompt user
    if [ -z "$server_type" ]; then
      if [[ "$NON_INTERACTIVE" == "true" ]]; then
        server_type=$(detect_server_type)
        log_info "Auto-detected server type: $server_type"
      else
        echo "Enter the server type (VPS1-VPS7 or DSCPU1-DSCPU5):"
        read -r server_type
      fi
    fi
  fi
  
  log_info "Configuring Redis for server type: $server_type"
  print_info "Configuring Redis for server type: $server_type"
  
  # Calculate optimal Redis memory
  local cache_size=$(calculate_redis_memory "$server_type")
  log_info "Calculated Redis cache size: $cache_size"
  
  # Check if Redis is already installed
  if ! systemctl is-active --quiet redis; then
    log_info "Redis not active. Installing Redis..."
    print_info "Installing Redis..."
       
    # Install Remi repo if needed
    if ! rpm -q remi-release > /dev/null; then
      install_remi_repo "$release" || {
        log_error "Failed to install required Remi repository"
        print_error "Failed to install required Remi repository"
        return 1
      }
    fi
    
    # Install Redis with error handling
    log_info "Installing Redis package..."
    if ! yum -y install redis --enablerepo=remi --disableplugin=priorities; then
      log_error "Failed to install Redis"
      print_error "Failed to install Redis"
      return 1
    fi
    
    log_info "Enabling Redis service..."
    if ! systemctl enable redis; then
      log_error "Failed to enable Redis service"
      print_error "Failed to enable Redis service"
      return 1
    fi
    
    log_info "Starting Redis service..."
    if ! systemctl start redis; then
      log_error "Failed to start Redis"
      print_error "Failed to start Redis"
      return 1
    fi
  else
    log_info "Redis is already installed and running"
    print_info "Redis is already installed and running"
  fi
  
  # Locate Redis configuration file
  log_info "Locating Redis configuration file..."
  local redis_conf
  if [ -f "/etc/redis/redis.conf" ]; then
    redis_conf="/etc/redis/redis.conf"
  elif [ -f "/etc/redis.conf" ]; then
    redis_conf="/etc/redis.conf"
  else
    log_error "Redis configuration file not found"
    print_error "Redis configuration file not found"
    return 1
  fi
  
  log_info "Using Redis configuration file: $redis_conf"
  print_info "Using Redis configuration file: $redis_conf"
  
  # Backup original configuration
  backup_file "$redis_conf" || {
    log_error "Failed to backup Redis configuration"
    print_error "Failed to backup Redis configuration"
    return 1
  }
  
  # Configure Redis with optimal settings
  log_info "Applying optimized Redis configuration..."
  print_info "Applying optimized Redis configuration..."
  
  {
    echo "# Redis configuration for $server_type"
    echo "# Generated on $(date) by Server Optimizer"
    echo ""
    echo "# Directory Configuration"
    echo "dir /var/lib/redis"
    echo "dbfilename dump.rdb"
    echo ""
    echo "# Memory Management"
    echo "maxmemory $cache_size"
    echo "maxmemory-policy allkeys-lru"
    echo "maxmemory-samples 10"
    echo ""
    echo "# Performance Tuning"
    echo "appendonly no"
    echo "appendfsync everysec"
    echo "no-appendfsync-on-rewrite yes"
    echo "activerehashing yes"
    echo "rdbcompression yes"
    echo "rdbchecksum yes"
    echo ""
    echo "# Connection Management"
    echo "timeout 300"
    echo "tcp-keepalive 60"
    echo "maxclients 10000"
    echo ""
    echo "# Logging"
    echo "loglevel notice"
    echo "databases $REDIS_DB_LIMIT"
  } > "$redis_conf"
  
  # Ensure Redis directory exists with correct permissions
  log_info "Setting up Redis data directory..."
  if [ ! -d "/var/lib/redis" ]; then
    mkdir -p /var/lib/redis
    log_info "Created Redis data directory"
  fi
  
  chown redis:redis /var/lib/redis
  chmod 750 /var/lib/redis
  
  # Restart Redis to apply changes
  log_info "Restarting Redis service to apply changes..."
  print_info "Restarting Redis service..."
  
  if ! systemctl restart redis; then
    log_error "Failed to restart Redis with new configuration"
    print_error "Failed to restart Redis with new configuration"
    
    # Restore backup
    log_warn "Restoring original configuration..."
    if ! cp -f "${redis_conf}.bak."* "$redis_conf" 2>/dev/null; then
      log_error "Failed to restore original Redis configuration"
      print_error "Failed to restore original Redis configuration"
    else
      if ! systemctl restart redis; then
        log_error "Failed to restart Redis with original configuration"
        print_error "Failed to restart Redis with original configuration"
      else
        log_info "Redis restarted with original configuration"
        print_info "Redis restarted with original configuration"
      fi
    fi
    
    return 1
  fi
  
  # Install Redis extension for PHP versions
  log_info "Installing Redis PHP extensions..."
  print_info "Installing Redis PHP extensions..."
  
  local install_errors=0
  for php in $(whmapi1 php_get_installed_versions | grep -oE '\bea-php[0-9]+'); do
    log_info "Installing Redis extension for $php..."
    if ! install_php_pecl_extension "$php"; then
      log_warn "Warning: Failed to install Redis extension for $php"
      print_warning "Warning: Failed to install Redis extension for $php"
      ((install_errors++))
    else
      log_info "Successfully installed Redis extension for $php"
    fi
  done
  
  # Final status check
  if systemctl is-active --quiet redis; then
    log_info "Redis installation and configuration complete"
    print_success "Redis installation and configuration complete"
    log_info "Cache Size: $cache_size"
    print_info "Cache Size: $cache_size"
    log_info "Configuration: $redis_conf"
    print_info "Configuration: $redis_conf"
    
    if [ $install_errors -gt 0 ]; then
      log_warn "Warning: Some PHP extensions failed to install"
      print_warning "Warning: Some PHP extensions failed to install"
    fi
    
    return 0
  else
    log_error "Error: Redis is not running after configuration"
    print_error "Error: Redis is not running after configuration"
    return 1
  fi
}

# Function to install PHP PECL extensions for Redis
install_php_pecl_extension() {
  local php_version=$1
  local php_major_version
  local php_minor_version

  # Get PHP version information
  if [ ! -f "/opt/cpanel/$php_version/root/usr/bin/php" ]; then
    log_error "PHP binary not found for $php_version"
    return 1
  fi
  
  php_major_version=$(/opt/cpanel/"$php_version"/root/usr/bin/php -r 'echo PHP_MAJOR_VERSION;')
  php_minor_version=$(/opt/cpanel/"$php_version"/root/usr/bin/php -r 'echo PHP_MINOR_VERSION;')

  # Skip older PHP versions
  if (( php_major_version < 7 )); then
    log_info "Skipping installation of PECL extensions for PHP $php_version (version < 7.0.0)"
    return 0
  elif (( php_major_version == 7 && php_minor_version < 2 )); then
    log_info "Skipping installation of PECL redis extension for PHP $php_version (version < 7.2.0)"
    return 0
  fi

  log_info "Installing PECL extension for $php_version"
  
  # Install igbinary and redis extensions
  if ! echo -e "\n\n\n" | /opt/cpanel/"$php_version"/root/usr/bin/pecl install igbinary igbinary-devel redis; then
    log_error "Failed to install PECL extensions for $php_version"
    return 1
  fi
  
  log_info "PHP PECL extension for $php_version installed successfully"
  return 0
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Run the function
  install_configure_redis
fi
