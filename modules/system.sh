#!/bin/bash
#
# Module: System Optimization
# Description: Functions for optimizing system settings
#
# This module contains functions for configuring system limits,
# kernel parameters, and other system-level optimizations.

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

# Function to disable IPv6
disable_ipv6() {
  log_info "Disabling IPv6..."
  print_section "Disabling IPv6"
  
  # Backup existing sysctl.conf
  backup_file "/etc/sysctl.conf" || {
    log_error "Failed to backup /etc/sysctl.conf"
    return 1
  }
  
  # Check if IPv6 settings already exist
  local ipv6_all=$(grep -c "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf)
  local ipv6_default=$(grep -c "net.ipv6.conf.default.disable_ipv6" /etc/sysctl.conf)
  local ipv6_lo=$(grep -c "net.ipv6.conf.lo.disable_ipv6" /etc/sysctl.conf)
  
  # Update or add IPv6 settings
  if [ $ipv6_all -gt 0 ]; then
    sed -i 's/^net.ipv6.conf.all.disable_ipv6.*/net.ipv6.conf.all.disable_ipv6 = 1/' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  
  if [ $ipv6_default -gt 0 ]; then
    sed -i 's/^net.ipv6.conf.default.disable_ipv6.*/net.ipv6.conf.default.disable_ipv6 = 1/' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  
  if [ $ipv6_lo -gt 0 ]; then
    sed -i 's/^net.ipv6.conf.lo.disable_ipv6.*/net.ipv6.conf.lo.disable_ipv6 = 1/' /etc/sysctl.conf
  else
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
  fi
  
  # Apply settings
  log_info "Applying IPv6 settings..."
  if sysctl -p; then
    log_info "IPv6 has been disabled successfully."
    print_success "IPv6 has been disabled successfully."
  else
    log_warn "Some sysctl changes might not have been applied. Please check sysctl.conf manually."
    print_warning "Some sysctl changes might not have been applied. Please check sysctl.conf manually."
  fi
  
  # Verify settings
  local all_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
  local default_status=$(sysctl -n net.ipv6.conf.default.disable_ipv6)
  local lo_status=$(sysctl -n net.ipv6.conf.lo.disable_ipv6)
  
  log_info "Current IPv6 settings:"
  log_info "net.ipv6.conf.all.disable_ipv6 = $all_status"
  log_info "net.ipv6.conf.default.disable_ipv6 = $default_status"
  log_info "net.ipv6.conf.lo.disable_ipv6 = $lo_status"
  
  print_info "Current IPv6 settings:"
  print_info "net.ipv6.conf.all.disable_ipv6 = $all_status"
  print_info "net.ipv6.conf.default.disable_ipv6 = $default_status"
  print_info "net.ipv6.conf.lo.disable_ipv6 = $lo_status"
  
  return 0
}

# Calculate nf_conntrack_max based on RAM and CPU cores
calculate_conntrack_max() {
  local ram_gb=$1
  local cpus=$2
  local server_type=$3
  
  # Base calculation: RAM(GB) * 1024 * cores
  local base_value=$((ram_gb * 1024 * cpus))
  
  # Set minimum and maximum bounds
  local min_value=32768    # Minimum reasonable value
  local max_value=524288   # Maximum reasonable value
  
  # Adjust based on server category
  case "$server_type" in
    VPS*)
      # VPS servers: be more conservative but still adequate
      [ $base_value -gt 262144 ] && base_value=262144
      min_value=32768
      ;;
    DSCPU*)
      # Dedicated servers: allow more aggressive values
      [ $base_value -gt 524288 ] && base_value=524288
      min_value=65536
      ;;
    *)
      # Default case: use moderate values
      [ $base_value -gt 262144 ] && base_value=262144
      min_value=32768
      ;;
  esac
  
  # Ensure value is within bounds
  [ $base_value -lt $min_value ] && base_value=$min_value
  [ $base_value -gt $max_value ] && base_value=$max_value
  
  # Round to nearest power of 2
  local power=1
  while [ $power -lt $base_value ]; do
    power=$((power * 2))
  done
  
  echo $power
}

# Function to configure system limits
configure_system_limits() {
  print_section "Configuring System Limits"
  log_info "Starting system limits configuration"
  
  # If server_type is not already set in the environment, prompt for it
  if [ -z "$SERVER_TYPE" ]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      SERVER_TYPE=$(detect_server_type)
      log_info "Auto-detected server type: $SERVER_TYPE"
    else
      echo "Enter the server type (VPS1-VPS7 or DSCPU1-DSCPU5):"
      read -r SERVER_TYPE
    fi
  fi

  log_info "Configuring system limits for $SERVER_TYPE..."
  print_info "Configuring system limits for $SERVER_TYPE..."

  # Define RAM and CPU configurations based on server type
  case "$SERVER_TYPE" in
    VPS1) ram_gb=2;  cpus=1 ;;
    VPS2) ram_gb=4;  cpus=2 ;;
    VPS3) ram_gb=8;  cpus=4 ;;
    VPS4) ram_gb=16; cpus=6 ;;
    VPS5) ram_gb=32; cpus=8 ;;
    VPS6) ram_gb=64; cpus=16 ;;
    VPS7) ram_gb=96; cpus=20 ;;
    DSCPU1) ram_gb=4;  cpus=2 ;;
    DSCPU2) ram_gb=8;  cpus=4 ;;
    DSCPU3) ram_gb=16; cpus=8 ;;
    DSCPU4) ram_gb=32; cpus=16 ;;
    DSCPU5) ram_gb=64; cpus=32 ;;
    *) 
      log_error "Invalid server type: $SERVER_TYPE"
      print_error "Invalid server type: $SERVER_TYPE"
      return 1 
      ;;
  esac

  # Ensure we have valid CPU and RAM values
  if [[ -z "$CPU_CORES" || -z "$TOTAL_RAM_MB" ]]; then
    get_server_resources >/dev/null
  fi
  
  # If detected resources are significantly different, warn user
  local detected_ram_gb=$((TOTAL_RAM_MB / 1024))
  if [ "$detected_ram_gb" -lt "$((ram_gb * 75 / 100))" ] || [ "$detected_ram_gb" -gt "$((ram_gb * 125 / 100))" ]; then
    log_warn "Selected RAM ($ram_gb GB) differs from detected RAM ($detected_ram_gb GB)"
    print_warning "Selected RAM ($ram_gb GB) differs from detected RAM ($detected_ram_gb GB)"
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
      if ! ask_yes_no "Continue with selected server type?" "y"; then
        log_info "User cancelled operation"
        return 1
      fi
    fi
  fi
  
  if [ "$CPU_CORES" -lt "$((cpus * 75 / 100))" ] || [ "$CPU_CORES" -gt "$((cpus * 125 / 100))" ]; then
    log_warn "Selected CPUs ($cpus) differs from detected CPUs ($CPU_CORES)"
    print_warning "Selected CPUs ($cpus) differs from detected CPUs ($CPU_CORES)"
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
      if ! ask_yes_no "Continue with selected server type?" "y"; then
        log_info "User cancelled operation"
        return 1
      fi
    fi
  fi

  # Convert RAM to KB for calculations
  local ram_kb=$((ram_gb * 1024 * 1024))

  # Calculate memory-based parameters
  # admin_reserve_kbytes: 3% for systems under 64GB, 1.5% for larger systems
  local admin_reserve_kb
  if [ $ram_gb -lt 64 ]; then
    admin_reserve_kb=$((ram_kb * 3 / 100))
  else
    admin_reserve_kb=$((ram_kb * 15 / 1000))
  fi

  # min_free_kbytes: ~1.5% of RAM, adjusted for server size
  local min_free_kb=$((ram_kb * 15 / 1000))
  
  # Adjust min_free_kb based on server category
  case "$SERVER_TYPE" in
    VPS*) 
      # VPS servers: be more conservative with memory
      [ $min_free_kb -gt 262144 ] && min_free_kb=262144 ;;
    DSCPU*)
      # Dedicated servers: allow more aggressive values
      [ $min_free_kb -gt 524288 ] && min_free_kb=524288 ;;
  esac

  # Backup existing configuration files
  log_info "Backing up configuration files"
  backup_file "/etc/security/limits.conf" || {
    log_error "Failed to backup /etc/security/limits.conf"
    return 1
  }
  
  backup_file "/etc/sysctl.conf" || {
    log_error "Failed to backup /etc/sysctl.conf"
    return 1
  }

  log_info "Creating new limits configuration..."
  print_info "Creating new limits configuration..."
  
  # Update /etc/security/limits.conf
  cat > /etc/security/limits.conf <<EOF
# Performance Tuning - Configured for $SERVER_TYPE
# Configuration generated on $(date)
# By Server Optimizer

# Process limits
*       soft    nproc   $((cpus * 4096))
*       hard    nproc   $((cpus * 8192))
*       soft    nofile  999999
*       hard    nofile  999999

# Root limits
root    soft    nproc   $((cpus * 2048))
root    hard    nproc   $((cpus * 4096))
root    soft    nofile  999999
root    hard    nofile  999999

# Memory limits
*       soft    memlock unlimited
*       hard    memlock unlimited
EOF

  log_info "Creating new sysctl configuration..."
  print_info "Creating new sysctl configuration..."
  
  # Update /etc/sysctl.conf
  cat > /etc/sysctl.conf <<EOF
# Performance Tuning - Configured for $SERVER_TYPE
# Configuration generated on $(date)
# By Server Optimizer

# Memory Management
vm.swappiness = $([ $ram_gb -le 4 ] && echo "10" || echo "0")
vm.overcommit_memory = 1
vm.admin_reserve_kbytes = $admin_reserve_kb
vm.min_free_kbytes = $min_free_kb
vm.panic_on_oom = 0
vm.dirty_ratio = 20
vm.dirty_background_ratio = 3
vm.vfs_cache_pressure = 70

# Network Optimization
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = $((cpus * 32768))
net.core.somaxconn = $((cpus * 16384)) 
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fin_timeout = 30

# File System and Limits
fs.file-max = $((ram_kb / 2))
fs.nr_open = 999999
fs.inotify.max_user_watches = 524288

# TCP Optimization
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_max_syn_backlog = $((cpus * 65536))
net.ipv4.tcp_max_tw_buckets = $((cpus * 262144))
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1

# Connection Tracking
net.netfilter.nf_conntrack_max = $(calculate_conntrack_max $ram_gb $cpus $SERVER_TYPE)
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.ipv4.netfilter.ip_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close = 10

# Additional Network Settings
net.ipv4.ip_nonlocal_bind = 1

# Enhanced TCP Settings
net.ipv4.tcp_max_orphans = $((ram_kb / 32768))
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_fastopen = 3
net.core.optmem_max = 25165824
EOF

  log_info "Applying new configurations..."
  print_info "Applying new configurations..."
  
  # Handle Transparent Huge Pages
  if [ -d "/sys/kernel/mm/transparent_hugepage" ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    
    # Make THP settings persistent
    if [ ! -f "/etc/rc.local" ] || ! grep -q "transparent_hugepage" "/etc/rc.local"; then
      echo '#!/bin/bash' > /etc/rc.local
      echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
      echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.local
      chmod +x /etc/rc.local
      log_info "Added THP settings to rc.local"
    fi
  fi

  # Apply sysctl changes
  if sysctl -p; then
    log_info "Successfully applied sysctl changes"
    print_success "Successfully applied sysctl changes"
  else
    log_warn "Some sysctl changes could not be applied. Please check sysctl.conf manually."
    print_warning "Some sysctl changes could not be applied. Please check sysctl.conf manually."
  fi

  log_info "System limits configuration complete."
  print_success "System limits configuration complete."
  
  return 0
}

# If the script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Run the function
  configure_system_limits
fi
