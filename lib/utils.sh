#!/bin/bash
#
# Utility functions for Server Optimizer
# This library provides common utility functions

# Set library directory path
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"

# Check if script is run as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_fatal "This script must be run as root"
    exit 1
  fi
}

# Check OS version
check_os_version() {
  # Check if this is a RHEL/CentOS/CloudLinux system
  if [[ ! -f /etc/redhat-release ]]; then
    log_fatal "This script is designed for RHEL/CentOS/CloudLinux systems only"
    exit 1
  fi
  
  # Get OS version
  local release_version
  release_version=$(rpm -q --qf %{version} "$(rpm -q --whatprovides redhat-release)" | cut -c 1)
  
  # Check if version is supported
  if [[ ! $release_version =~ [789] ]]; then
    log_fatal "Unsupported OS version: $release_version. This script supports RHEL/CentOS/CloudLinux 7, 8, and 9."
    exit 1
  fi
  
  # Return the version
  echo "$release_version"
}

# Check if cPanel is installed
check_cpanel() {
  if [[ ! -d /usr/local/cpanel ]]; then
    log_fatal "cPanel/WHM is not installed. This script requires cPanel/WHM."
    exit 1
  fi
  
  # Check cPanel version
  local cpanel_version
  cpanel_version=$(/usr/local/cpanel/cpanel -V 2>/dev/null)
  log_info "cPanel version: $cpanel_version"
}

# Ask yes/no question
ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  
  if [[ $default == "y" ]]; then
    prompt="$prompt [Y/n]: "
  else
    prompt="$prompt [y/N]: "
  fi
  
  while true; do
    read -r -p "$prompt" answer
    answer=${answer:-$default}
    case ${answer,,} in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        echo "Please answer yes or no."
        ;;
    esac
  done
}

# Backup a file with timestamp
backup_file() {
  local file="$1"
  
  if [[ -f "$file" ]]; then
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${file}.bak.${timestamp}"
    
    if cp -f "$file" "$backup_file"; then
      log_info "Backed up $file to $backup_file"
      return 0
    else
      log_error "Failed to backup $file"
      return 1
    fi
  else
    log_warn "File does not exist, cannot backup: $file"
    return 1
  fi
}

# Function to get server resources
get_server_resources() {
  local cpu_cores
  local total_ram_mb
  
  cpu_cores=$(nproc)
  total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
  
  echo "CPU Cores: $cpu_cores"
  echo "Total RAM (MB): $total_ram_mb"
  
  # Export as variables
  export CPU_CORES="$cpu_cores"
  export TOTAL_RAM_MB="$total_ram_mb"
}

# Function to detect server type based on resources
detect_server_type() {
  if [[ -z "$CPU_CORES" || -z "$TOTAL_RAM_MB" ]]; then
    get_server_resources >/dev/null
  fi
  
  local ram_gb=$((TOTAL_RAM_MB / 1024))
  
  # Determine if this is likely a VPS or dedicated server
  # This is a simple heuristic - you may want to adjust this
  local server_prefix
  if [[ $CPU_CORES -gt 8 || $ram_gb -gt 32 ]]; then
    server_prefix="DSCPU"
  else
    server_prefix="VPS"
  fi
  
  # Determine size category
  local size_category
  if [[ $ram_gb -le 2 ]]; then
    size_category="1"
  elif [[ $ram_gb -le 4 ]]; then
    size_category="2"
  elif [[ $ram_gb -le 8 ]]; then
    size_category="3"
  elif [[ $ram_gb -le 16 ]]; then
    size_category="4"
  elif [[ $ram_gb -le 32 ]]; then
    size_category="5"
  elif [[ $ram_gb -le 64 ]]; then
    size_category="6"
  elif [[ $ram_gb -le 96 ]]; then
    size_category="7"
  else
    size_category="8"
  fi
  
  local server_type="${server_prefix}${size_category}"
  log_info "Detected server type: $server_type (${ram_gb}GB RAM, ${CPU_CORES} CPU cores)"
  
  echo "$server_type"
}
