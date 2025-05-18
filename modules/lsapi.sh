#!/bin/bash
#
# Module: LSAPI Optimization
# Description: Functions for installing and configuring LSAPI
#
# This module contains functions for installing and optimizing LSAPI
# for improved PHP performance in cPanel environments.

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Function to analyze PHP memory requirements across domains
analyze_php_memory_requirements() {
  print_section "Analyzing PHP Memory Requirements"
  log_info "Starting PHP memory requirements analysis"
  
  local total_memory=0
  local domain_count=0
  local max_memory=0
  local memory_data=""
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local report_dir="/root/lsapi_reports"
  
  mkdir -p "$report_dir"
  log_info "Created reports directory: $report_dir"
  
  # Get all domains from WHM API
  print_info "Gathering domain information..."
  local domains_info
  domains_info=$(whmapi1 --output=jsonpretty get_domain_info | jq -r '.data.domains[] | select(.domain_type == "main" or .domain_type == "addon") | .domain')
  
  if [ -z "$domains_info" ]; then
    log_error "Failed to retrieve domain information"
    print_error "Failed to retrieve domain information from WHM API"
    return 128
  fi
  
  log_info "Found domains to analyze"

  # Create report file with timestamp
  local report_file="${report_dir}/memory_analysis_${timestamp}.csv"
  echo "Domain,PHP Version,Memory Limit (MB),Document Root,Custom php.ini Found,Memory Source" > "$report_file"

  # Create debug log file
  local debug_log="${report_dir}/php_config_debug_${timestamp}.log"
  echo "PHP Configuration Analysis Debug Log - $(date)" > "$debug_log"

  # Array to store PHP versions and their memory limits
  declare -A php_version_counts
  declare -A php_version_memory

  # Parse memory limit value function
  parse_memory_limit() {
    local limit=$1
    local value

    # Remove any whitespace
    limit=$(echo "$limit" | tr -d ' ')

    # Check for unlimited
    if [ "$limit" = "-1" ]; then
      echo "512"
      return
    fi

    # Extract number and unit
    if [[ $limit =~ ^([0-9]+)([KMG])?B?$ ]]; then
      value=${BASH_REMATCH[1]}
      unit=${BASH_REMATCH[2]}

      case ${unit^^} in
        G) value=$((value * 1024)) ;;
        K) value=$((value / 1024)) ;;
        M|"") value=$value ;;
        *) value=128 ;;
      esac

      echo "$value"
    else
      echo "128"  # Default if format is invalid
    fi
  }

  log_info "Analyzing PHP memory requirements across all domains..."
  print_info "Analyzing PHP memory requirements across all domains..."
  print_info "This may take a few minutes depending on the number of domains..."

  # Analyze each domain
  while IFS= read -r domain; do
    log_info "Analyzing domain: $domain"
    
    # Get domain user data
    local domain_data
    domain_data=$(whmapi1 domainuserdata domain="$domain")
    
    # Extract document root and PHP version
    local docroot
    local php_version
    docroot=$(echo "$domain_data" | awk '/documentroot:/ {print $2}')
    php_version=$(echo "$domain_data" | awk '/phpversion:/ {print $2}')
    
    if [ -z "$docroot" ] || [ -z "$php_version" ]; then
      log_warn "Could not determine document root or PHP version for $domain"
      echo "Warning: Could not determine document root or PHP version for $domain" >> "$debug_log"
      continue
    fi

    # Check if directory exists
    if [ ! -d "$docroot" ]; then
      log_warn "Document root $docroot does not exist for $domain"
      echo "Warning: Document root $docroot does not exist for $domain" >> "$debug_log"
      continue
    fi

    # Get PHP binary path
    local php_binary="/opt/cpanel/$php_version/root/usr/bin/php"
    if [ ! -x "$php_binary" ]; then
      log_warn "PHP binary not found at $php_binary for $domain"
      echo "Warning: PHP binary not found at $php_binary for $domain" >> "$debug_log"
      continue
    fi

    # Get base memory limit from PHP
    local memory_limit
    local memory_source="php.ini"
    memory_limit=$($php_binary -r 'echo ini_get("memory_limit");')
    
    # Convert the memory limit to MB
    memory_limit=$(parse_memory_limit "$memory_limit")
    
    # Check for custom php.ini in document root
    local custom_ini="No"
    local custom_limit
    if [ -f "${docroot}/php.ini" ]; then
      custom_ini="Yes"
      custom_limit=$(grep -i "^memory_limit" "${docroot}/php.ini" | awk -F'=' '{print $2}' | tr -d ' ')
      if [ ! -z "$custom_limit" ]; then
        local parsed_custom=$(parse_memory_limit "$custom_limit")
        if [ "$parsed_custom" -gt "$memory_limit" ]; then
          memory_limit=$parsed_custom
          memory_source="custom php.ini"
        fi
      fi
    fi

    # Check for .user.ini
    if [ -f "${docroot}/.user.ini" ]; then
      local user_limit=$(grep -i "^memory_limit" "${docroot}/.user.ini" | awk -F'=' '{print $2}' | tr -d ' ')
      if [ ! -z "$user_limit" ]; then
        local parsed_user=$(parse_memory_limit "$user_limit")
        if [ "$parsed_user" -gt "$memory_limit" ]; then
          memory_limit=$parsed_user
          memory_source=".user.ini"
          custom_ini="Yes (.user.ini)"
        fi
      fi
    fi

    # Ensure minimum reasonable value
    if [ "$memory_limit" -lt 32 ]; then
      memory_limit=128
      memory_source="default minimum"
    fi

    # Update statistics
    total_memory=$((total_memory + memory_limit))
    domain_count=$((domain_count + 1))
    if [ "$memory_limit" -gt "$max_memory" ]; then
      max_memory=$memory_limit
    fi

    # Update PHP version statistics
    : "${php_version_counts[$php_version]:=0}"
    : "${php_version_memory[$php_version]:=0}"
    php_version_counts[$php_version]=$((php_version_counts[$php_version] + 1))
    php_version_memory[$php_version]=$((php_version_memory[$php_version] + memory_limit))

    # Store domain data
    echo "$domain,$php_version,$memory_limit,$docroot,$custom_ini,$memory_source" >> "$report_file"
    
  done <<< "$domains_info"

  # Calculate average with 20% overhead for safety
  local average_memory=256  # Default if no domains found
  if [ "$domain_count" -gt 0 ]; then
    average_memory=$(( (total_memory / domain_count) * 12 / 10 ))
  fi

  # Ensure minimum memory allocation
  if [ "$average_memory" -lt 256 ]; then
    average_memory=256
  fi

  # Create and print summary
  local summary_file="$report_dir/memory_analysis_summary_${timestamp}.txt"
  {
    echo "PHP Memory Analysis Summary"
    echo "=========================="
    echo "Report generated on: $(date)"
    echo ""
    echo "General Statistics:"
    echo "-----------------"
    echo "Total domains analyzed: $domain_count"
    echo "Average memory limit (with 20% overhead): ${average_memory}MB"
    echo "Maximum memory limit found: ${max_memory}MB"
    echo ""
    echo "PHP Version Distribution:"
    echo "----------------------"
    for version in "${!php_version_counts[@]}"; do
      local count=${php_version_counts["$version"]}
      local avg_mem=0
      if [ "$count" -gt 0 ]; then
        avg_mem=$((${php_version_memory["$version"]} / count))
      fi
      echo "PHP $version:"
      echo "  Count: $count domains"
      echo "  Average memory limit: ${avg_mem}MB"
    done
    echo ""
    echo "Report Files:"
    echo "------------"
    echo "Detailed analysis: $report_file"
    echo "Debug log: $debug_log"
  } > "$summary_file"

  # Display the summary
  log_info "Memory analysis complete"
  print_success "Memory analysis complete"
  print_info "Average memory requirement (with overhead): ${average_memory}MB"
  print_info "Summary saved to: $summary_file"

  # Return the average memory value
  echo "$average_memory"
}

# Function to calculate optimal LSAPI settings based on server resources
calculate_lsapi_settings() {
  local server_type=$1
  local CPU_CORES=$(nproc)
  local TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  
  print_section "Calculating LSAPI Settings"
  log_info "Calculating LSAPI settings for server type: $server_type"
  log_info "Server has $CPU_CORES CPU cores and ${TOTAL_RAM_MB}MB RAM"
  
  # Validate server type
  if [ -z "$server_type" ]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      server_type=$(detect_server_type)
      log_info "Auto-detected server type: $server_type"
    else
      echo "Enter the server type (VPS1-VPS8 or DSCPU1-DSCPU9):"
      read -r server_type
    fi
  fi
  
  print_info "Configuring LSAPI for server type: $server_type"
  
  # Define settings based on server type
  case "$server_type" in
    VPS1) # 2GB RAM, 1 CPU
      CHILDREN=35
      MAX_PROCESS_MEM=48
      MAX_IDLE=180
      MAX_REQS=2000
      INITIAL_START=12
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=12
      MAX_CRASHES=10
      PGRP_MAX_CRASHES=20
      CONNECT_TRIES=15
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS2) # 4GB RAM, 2 CPUs
      CHILDREN=35  # (85% of 4GB = 3.4GB; 3400MB/85MB = ~40 processes)
      MAX_PROCESS_MEM=85
      MAX_IDLE=180
      MAX_REQS=4000
      INITIAL_START=12
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=12
      MAX_CRASHES=12
      PGRP_MAX_CRASHES=25
      CONNECT_TRIES=20
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS3) # 8GB RAM, 4 CPUs
      CHILDREN=70  # (~17.5 per core)
      MAX_PROCESS_MEM=96
      MAX_IDLE=240
      MAX_REQS=8000
      INITIAL_START=20
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=20
      MAX_CRASHES=15
      PGRP_MAX_CRASHES=30
      CONNECT_TRIES=25
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS4) # 16GB RAM, 6 CPUs
      CHILDREN=90  # (~15 per core)
      MAX_PROCESS_MEM=128
      MAX_IDLE=300
      MAX_REQS=16000
      INITIAL_START=25
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=25
      MAX_CRASHES=20
      PGRP_MAX_CRASHES=40
      CONNECT_TRIES=30
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS5) # 32GB RAM, 8 CPUs
      CHILDREN=120  # (~15 per core)
      MAX_PROCESS_MEM=192
      MAX_IDLE=360
      MAX_REQS=32000
      INITIAL_START=30
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=30
      MAX_CRASHES=25
      PGRP_MAX_CRASHES=50
      CONNECT_TRIES=35
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS6) # 64GB RAM, 16 CPUs
      CHILDREN=160  # (~10 per core)
      MAX_PROCESS_MEM=256
      MAX_IDLE=420
      MAX_REQS=64000
      INITIAL_START=40
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=40
      MAX_CRASHES=30
      PGRP_MAX_CRASHES=60
      CONNECT_TRIES=40
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    VPS7|VPS8) # 96GB+ RAM, 20+ CPUs
      CHILDREN=200
      MAX_PROCESS_MEM=384
      MAX_IDLE=480
      MAX_REQS=100000
      INITIAL_START=50
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=50
      MAX_CRASHES=35
      PGRP_MAX_CRASHES=70
      CONNECT_TRIES=45
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    DSCPU*) 
      # More aggressive calculations for dedicated servers
      local ram_gb=$((TOTAL_RAM_MB / 1024))
      local base_children=$((CPU_CORES * 15))  # 15 processes per core
      
      # Calculate children based on available RAM
      local available_ram=$((TOTAL_RAM_MB * 85 / 100))
      local target_mem_per_process=128  # Start with 128MB target
      
      CHILDREN=$base_children
      MAX_PROCESS_MEM=$target_mem_per_process
      
      # Calculate total memory usage
      local total_mem=$((CHILDREN * MAX_PROCESS_MEM))
      
      # Adjust if we're using too much memory
      if [ $total_mem -gt $available_ram ]; then
        # Try to maintain children count by reducing memory per process
        MAX_PROCESS_MEM=$((available_ram / CHILDREN))
        if [ $MAX_PROCESS_MEM -lt 64 ]; then
          # If memory per process gets too low, reduce children instead
          MAX_PROCESS_MEM=64
          CHILDREN=$((available_ram / MAX_PROCESS_MEM))
        fi
      fi
      
      # Set other values based on server capacity
      MAX_IDLE=$((ram_gb * 10 + 180))  # Scale with RAM
      MAX_REQS=$((CHILDREN * 1000))
      INITIAL_START=$((CHILDREN / 4))
      MAX_PROCESS_TIME=300
      BACKEND_RESPAWN=$((CHILDREN / 4))
      MAX_CRASHES=$((10 + (CPU_CORES / 2)))
      PGRP_MAX_CRASHES=$((MAX_CRASHES * 2))
      CONNECT_TRIES=$((20 + (CPU_CORES / 2)))
      POLL_TIMEOUT=5000
      CONNECT_TIMEOUT=500
      ;;
    *)
      log_error "Invalid server type: $server_type"
      print_error "Invalid server type: $server_type"
      return 1
      ;;
  esac

  # Adjust for real server conditions
  local available_ram=$((TOTAL_RAM_MB * 85 / 100))
  local max_possible_children=$((available_ram / MAX_PROCESS_MEM))
  
  if [ "$CHILDREN" -gt "$max_possible_children" ]; then
    # Try to optimize by reducing memory first
    local min_process_mem=64  # Reduced minimum memory
    while [ "$CHILDREN" -gt "$max_possible_children" ] && [ "$MAX_PROCESS_MEM" -gt "$min_process_mem" ]; do
      MAX_PROCESS_MEM=$((MAX_PROCESS_MEM * 90 / 100))
      max_possible_children=$((available_ram / MAX_PROCESS_MEM))
    done
    
    # If still exceeding, adjust children
    if [ "$CHILDREN" -gt "$max_possible_children" ]; then
      CHILDREN=$max_possible_children
    fi
    
    # Adjust related settings proportionally
    INITIAL_START=$((CHILDREN / 4))
    BACKEND_RESPAWN=$((CHILDREN / 4))
    MAX_REQS=$((CHILDREN * 1000))  # Scale max requests with children
  fi

  # Final safety checks
  [ "$MAX_PROCESS_MEM" -lt 64 ] && MAX_PROCESS_MEM=64
  [ "$CHILDREN" -lt 20 ] && CHILDREN=20
  [ "$INITIAL_START" -lt 5 ] && INITIAL_START=5
  [ "$BACKEND_RESPAWN" -lt 5 ] && BACKEND_RESPAWN=5

  # Export settings
  export CHILDREN MAX_PROCESS_MEM MAX_IDLE MAX_REQS CONNECT_TIMEOUT POLL_TIMEOUT
  export INITIAL_START MAX_PROCESS_TIME BACKEND_RESPAWN MAX_CRASHES PGRP_MAX_CRASHES CONNECT_TRIES

  log_info "LSAPI Settings for $server_type:"
  log_info "Backend Children: $CHILDREN"
  log_info "Max Process Memory: ${MAX_PROCESS_MEM}MB"
  log_info "Max Idle: $MAX_IDLE"
  log_info "Max Requests: $MAX_REQS"
  log_info "Initial Start: $INITIAL_START"
  log_info "Backend Respawn: $BACKEND_RESPAWN"
  log_info "Max Crashes: $MAX_CRASHES"
  log_info "Process Group Max Crashes: $PGRP_MAX_CRASHES"
  log_info "Connect Tries: $CONNECT_TRIES"
  
  print_info "LSAPI Settings for $server_type:"
  print_info "Backend Children: $CHILDREN"
  print_info "Max Process Memory: ${MAX_PROCESS_MEM}MB"
  print_info "Max Idle: $MAX_IDLE"
  print_info "Max Requests: $MAX_REQS"
  
  return 0
}

# Function to install and configure mod_lsapi
install_mod_lsapi() {
  print_section "Installing and Configuring mod_lsapi"
  log_info "Starting mod_lsapi installation and configuration"
  
  # Check if mod_lsapi is already installed
  if rpm -q ea-apache24-mod_lsapi > /dev/null; then
    log_info "mod_lsapi is already installed"
    print_info "mod_lsapi is already installed"
  else
    log_info "Installing mod_lsapi..."
    print_info "Installing mod_lsapi..."
    
    if ! yum install -y ea-apache24-mod_lsapi.x86_64; then
      log_error "Failed to install mod_lsapi"
      print_error "Failed to install mod_lsapi"
      return 1
    fi
    
    log_info "mod_lsapi installed successfully"
    print_success "mod_lsapi installed successfully"
  fi

  # Create LSAPI monitoring directory and log files
  local LSAPI_MONITOR_DIR="/var/log/mod_lsapi"
  local LSAPI_MONITOR_LOG="${LSAPI_MONITOR_DIR}/lsapi_events.log"
  local LSAPI_CORE_DIR="/var/cores/mod_lsapi"
  
  mkdir -p "$LSAPI_MONITOR_DIR" "$LSAPI_CORE_DIR"
  touch "$LSAPI_MONITOR_LOG"
  chown root:root "$LSAPI_MONITOR_LOG" "$LSAPI_CORE_DIR"
  chmod 644 "$LSAPI_MONITOR_LOG"
  chmod 755 "$LSAPI_CORE_DIR"

  # Backup existing configuration
  if [ -f /etc/apache2/conf.d/lsapi.conf ]; then
    log_info "Backing up existing LSAPI configuration..."
    backup_file "/etc/apache2/conf.d/lsapi.conf" || {
      log_error "Failed to backup LSAPI configuration"
      print_error "Failed to backup LSAPI configuration"
      return 1
    }
  }

  # Get server resources
  local CPU_CORES=$(nproc)
  local TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  
  log_info "System has $CPU_CORES CPU cores and ${TOTAL_RAM_MB}MB RAM"
  print_info "System has $CPU_CORES CPU cores and ${TOTAL_RAM_MB}MB RAM"
  
  log_info "Analyzing PHP memory requirements..."
  print_info "Analyzing PHP memory requirements..."
  
  # Analyze PHP memory requirements
  local PROCESS_MEM_ESTIMATE=$(analyze_php_memory_requirements)
  
  # Validate memory estimate and ensure it's a number
  if ! [[ "$PROCESS_MEM_ESTIMATE" =~ ^[0-9]+$ ]]; then
    log_warn "Invalid memory estimate received (got: '$PROCESS_MEM_ESTIMATE'). Using default value of 256MB."
    print_warning "Invalid memory estimate received. Using default value of 256MB."
    PROCESS_MEM_ESTIMATE=256
  fi
  
  # Ensure minimum value
  if [ "$PROCESS_MEM_ESTIMATE" -lt 256 ]; then
    PROCESS_MEM_ESTIMATE=256
  fi
  
  log_info "Using process memory estimate: ${PROCESS_MEM_ESTIMATE}MB"
  print_info "Using process memory estimate: ${PROCESS_MEM_ESTIMATE}MB"
  
  # Constants for resource limits
  local MIN_PROCESS_MEM=$PROCESS_MEM_ESTIMATE
  local MAX_TOTAL_CHILDREN=150
  local MIN_TOTAL_CHILDREN=25

  # Ask for server type
  local SERVER_TYPE
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    SERVER_TYPE=$(detect_server_type)
    log_info "Auto-detected server type: $SERVER_TYPE"
  else
    echo "Enter the server type (VPS1-VPS8 or DSCPU1-DSCPU9):"
    read -r SERVER_TYPE
  fi

  # Calculate settings
  calculate_lsapi_settings "$SERVER_TYPE"

  # Create monitoring script
  log_info "Creating LSAPI monitoring script..."
  cat > "${LSAPI_MONITOR_DIR}/monitor_lsapi.sh" <<'EOF'
#!/bin/bash

LSAPI_LOG="/var/log/mod_lsapi/lsapi_events.log"
ALERT_THRESHOLD_CRASHES=5
ALERT_THRESHOLD_RESPAWNS=10
ALERT_WINDOW=300  # 5 minute window

# Initialize counters
declare -A crash_times=()
declare -A respawn_times=()

monitor_lsapi() {
    local current_time=$(date +%s)
    local cutoff_time=$((current_time - ALERT_WINDOW))
    
    # Clean old entries
    for timestamp in "${!crash_times[@]}"; do
        if [ "$timestamp" -lt "$cutoff_time" ]; then
            unset crash_times["$timestamp"]
        fi
    done
    for timestamp in "${!respawn_times[@]}"; do
        if [ "$timestamp" -lt "$cutoff_time" ]; then
            unset respawn_times["$timestamp"]
        fi
    done
}

# Use tail -F to monitor the log file continuously
tail -F "$LSAPI_LOG" | while read -r line; do
    if [[ "$line" == *"crashed"* ]]; then
        crash_times[$(date +%s)]=1
        monitor_lsapi
        
        if [ "${#crash_times[@]}" -ge "$ALERT_THRESHOLD_CRASHES" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: High number of LSAPI crashes detected (${#crash_times[@]} crashes in last 5 minutes)" >> "$LSAPI_LOG"
        fi
    elif [[ "$line" == *"respawned"* ]]; then
        respawn_times[$(date +%s)]=1
        monitor_lsapi
        
        if [ "${#respawn_times[@]}" -ge "$ALERT_THRESHOLD_RESPAWNS" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: High number of LSAPI respawns detected (${#respawn_times[@]} respawns in last 5 minutes)" >> "$LSAPI_LOG"
        fi
    fi
done
EOF

  chmod +x "${LSAPI_MONITOR_DIR}/monitor_lsapi.sh"

  # Create systemd service for monitoring
  log_info "Creating systemd service for LSAPI monitoring..."
  cat > /etc/systemd/system/lsapi-monitor.service <<EOF
[Unit]
Description=LSAPI Monitoring Service
After=httpd.service

[Service]
ExecStart=${LSAPI_MONITOR_DIR}/monitor_lsapi.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  # Create new LSAPI configuration with all calculated settings
  log_info "Creating LSAPI configuration..."
  cat > /etc/apache2/conf.d/lsapi.conf <<EOF

<IfModule lsapi_module>
    # Basic handler configuration
    lsapi_engine On
    AddType application/x-httpd-lsphp .php
    
    # Performance optimization settings
    lsapi_backend_children $CHILDREN
    lsapi_backend_max_idle $MAX_IDLE
    lsapi_backend_max_reqs $MAX_REQS
    lsapi_backend_max_process_time $MAX_PROCESS_TIME
    
    # Process management
    lsapi_backend_connect_tries $CONNECT_TRIES
    lsapi_backend_initial_start $INITIAL_START
    lsapi_backend_pgrp_max_reqs $MAX_REQS
    lsapi_backend_pgrp_max_crashes $PGRP_MAX_CRASHES
    lsapi_terminate_backends_on_exit On
    lsapi_avoid_zombies On
    lsapi_backend_accept_notify On

    # Process handling
    lsapi_use_suexec On
    lsapi_per_user On
    
    # Security settings
    lsapi_disable_reject_mode Off
    lsapi_check_document_root On
    lsapi_target_perm Off
    lsapi_paranoid Off
    
    # Debug and logging configuration
    lsapi_backend_coredump On
    lsapi_backend_use_own_log Off
    lsapi_backend_common_own_log Off
    lsapi_backend_loglevel_info Off
    
    # PHP settings
    lsapi_process_phpini On
    lsapi_enable_user_ini On
    lsapi_keep_http200 On
    lsapi_mod_php_behaviour On

    # Environment settings
    lsapi_set_env TEMP "/tmp"
    lsapi_set_env TMP "/tmp"
    lsapi_set_env TMPDIR "/tmp"
    lsapi_set_env_path /usr/local/bin:/usr/bin:/bin

    # Logging
    ErrorLog ${LSAPI_MONITOR_DIR}/lsapi_error.log
    CustomLog ${LSAPI_MONITOR_DIR}/lsapi_access.log combined
</IfModule>
EOF

  # Set permissions
  chown root:root /etc/apache2/conf.d/lsapi.conf
  chmod 644 /etc/apache2/conf.d/lsapi.conf

  # Enable and start monitoring service
  log_info "Enabling and starting LSAPI monitoring service..."
  systemctl daemon-reload
  systemctl enable lsapi-monitor
  systemctl start lsapi-monitor

  # Save configuration summary to a file and display it
  local summary="${LSAPI_MONITOR_DIR}/configuration_summary.log"
  {
    echo "LSAPI configuration complete. Settings:"
    echo "- Backend Children: $CHILDREN"
    echo "- Max Process Memory: ${MAX_PROCESS_MEM}M (Based on analysis: ${PROCESS_MEM_ESTIMATE}M)"
    echo "- Max Idle Time: ${MAX_IDLE}s"
    echo "- Connect Timeout: ${CONNECT_TIMEOUT}μs (Poll Timeout: ${POLL_TIMEOUT}μs)"
    echo "- Process Limits:"
    echo "  * Max Crashes: $MAX_CRASHES (Process Group: $PGRP_MAX_CRASHES)"
    echo "  * Backend Respawn: $BACKEND_RESPAWN"
    echo "  * Connect Tries: $CONNECT_TRIES"
    echo "- Core Dumps: Enabled (Directory: $LSAPI_CORE_DIR)"
    echo "- Monitoring: Enabled (Log: $LSAPI_MONITOR_LOG)"
    echo ""
    echo "Configuration files:"
    echo "- Main config: /etc/apache2/conf.d/lsapi.conf"
    echo "- Monitor log: $LSAPI_MONITOR_LOG"
    echo "- Core dumps: $LSAPI_CORE_DIR"
  } | tee "$summary"

  log_info "LSAPI configuration summary saved to: $summary"
  print_success "LSAPI installation and configuration complete"

  # Restart Apache if it's running
  if systemctl is-active --quiet httpd; then
    log_info "Restarting Apache..."
    print_info "Restarting Apache..."
    
    if systemctl restart httpd; then
      log_info "Apache restarted successfully"
      print_success "Apache restarted successfully"
    else
      log_error "Failed to restart Apache. Please check the logs."
      print_error "Failed to restart Apache. Please check the logs."
      return 1
    fi
  else
    log_warn "Apache is not running. Please start it to apply configuration."
    print_warning "Apache is not running. Please start it to apply configuration."
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
  install_mod_lsapi
fi
