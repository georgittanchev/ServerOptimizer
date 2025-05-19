#!/bin/bash
#
# Server Optimizer 
# Main script for optimizing cPanel servers
#
# This script orchestrates the optimization of various components
# of a cPanel server to improve performance and security.

# Determine script location (handle symlinks correctly)
if [[ -L "$0" ]]; then
  # If running through a symlink, get the real path
  SCRIPT_PATH="$(readlink -f "$0")"
  BASE_DIR="$(dirname "$SCRIPT_PATH")"
  echo "Running through symlink. SCRIPT_PATH=$SCRIPT_PATH, BASE_DIR=$BASE_DIR"
else
  # If running directly
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Running directly. BASE_DIR=$BASE_DIR"
fi

# Special cases handling
if [[ "$BASE_DIR" == "/usr/local/bin" ]]; then
  BASE_DIR="/usr/local/server-optimizer"
  echo "Special case: changed to $BASE_DIR"
fi

echo "Final BASE_DIR=$BASE_DIR"

# Fixed paths using absolute locations
MODULES_DIR="${BASE_DIR}/modules"
LIB_DIR="${BASE_DIR}/lib"
CONFIG_FILE="${BASE_DIR}/config/default.conf"
VERSION="1.0.0"

# Set global flags for libraries
export LOGGING_LOADED=false
export UTILS_LOADED=false
export UI_LOADED=false

# Source required libraries with absolute paths
if [[ -f "${LIB_DIR}/logging.sh" ]]; then
  source "${LIB_DIR}/logging.sh"
  export LOGGING_LOADED=true
else
  echo "ERROR: Required library not found: ${LIB_DIR}/logging.sh"
  exit 1
fi

if [[ -f "${LIB_DIR}/utils.sh" ]]; then
  source "${LIB_DIR}/utils.sh"
  export UTILS_LOADED=true
else
  echo "ERROR: Required library not found: ${LIB_DIR}/utils.sh"
  exit 1
fi

if [[ -f "${LIB_DIR}/ui.sh" ]]; then
  source "${LIB_DIR}/ui.sh"
  export UI_LOADED=true
else
  echo "ERROR: Required library not found: ${LIB_DIR}/ui.sh"
  exit 1
fi

# Initialize array of modules
MODULES=(
  "System Limits" 
  "Apache Optimization" 
  "MySQL Optimization" 
  "Redis Installation and Configuration" 
  "Engintron Installation" 
  "LSAPI Installation and Optimization" 
  "WordPress Redis Configuration" 
  "cPanel Tweak Settings" 
  "Bad Bot Blocker" 
  "Swap Management" 
  "Imunify360 Optimization" 
  "Apache MPM Optimization"
)

# Initialize arrays for module functions
MODULE_FUNCTIONS=(
  "configure_system_limits"
  "optimize_apache_settings"
  "configure_mysql"
  "install_configure_redis"
  "install_engintron"
  "install_mod_lsapi"
  "configure_wordpress_redis"
  "direct_modify_cpanel_tweak_settings"
  "implement_bad_bot_blocker"
  "manage_swap"
  "optimize_imunify360"
  "switch_apache_mpm"
)

# Initialize arrays for module scripts
MODULE_SCRIPTS=(
  "system.sh"
  "apache.sh"
  "mysql.sh"
  "redis.sh"
  "cpanel.sh"
  "lsapi.sh"
  "wordpress.sh"
  "cpanel.sh"
  "security.sh"
  "swap.sh"
  "imunify.sh"
  "apache.sh"
)

# Initialize arrays for module config flags
MODULE_FLAGS=(
  "CONFIGURE_SYSTEM_LIMITS"
  "OPTIMIZE_APACHE"
  "OPTIMIZE_MYSQL"
  "INSTALL_REDIS"
  "INSTALL_ENGINTRON"
  "INSTALL_MOD_LSAPI"
  "CONFIGURE_REDIS_WP"
  "MODIFY_CPANEL_TWEAKS"
  "IMPLEMENT_BAD_BOT_BLOCKER"
  "MANAGE_SWAP"
  "OPTIMIZE_IMUNIFY360"
  "SWITCH_APACHE_MPM"
)

# Function to display the banner
display_banner() {
  clear
  print_header "Server Optimizer v${VERSION}"
  echo "This script will optimize your cPanel server for better performance and security."
  echo "It will make changes to various system components based on your selection."
  echo ""
  echo "Author: Georgi Tanchev"
  echo "License: MIT"
  echo ""
}

# Function to load configuration from file
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Loading configuration from $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  else
    log_warn "Configuration file not found: $CONFIG_FILE"
    log_info "Using default settings"
  fi
}

# Function to source module files
load_modules() {
  log_info "Loading modules..."
  
  echo "BASE_DIR when loading modules: $BASE_DIR"
  echo "Looking for modules in: ${MODULES_DIR}"
  ls -la "${MODULES_DIR}" || echo "Directory not found or empty"
  
  # Export needed variables for modules
  export SERVER_TYPE
  export NON_INTERACTIVE
  export CONFIG_FILE
  export BACKUP_DIR
  
  for module_script in "${MODULE_SCRIPTS[@]}"; do
    local module_path="${MODULES_DIR}/${module_script}"
    echo "Checking for module at: $module_path"
    if [[ -f "$module_path" ]]; then
      log_debug "Loading module: $module_script"
      echo "Found module: $module_script"
      # shellcheck source=/dev/null
      source "$module_path"
    else
      log_error "Module not found: $module_script"
      echo "ERROR: Module not found at: $module_path"
      exit 1
    fi
  done
  
  log_info "All modules loaded successfully"
}

# Function to parse command-line arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--version)
        echo "Server Optimizer v${VERSION}"
        exit 0
        ;;
      -c|--config)
        if [[ -n "$2" && -f "$2" ]]; then
          CONFIG_FILE="$2"
          shift 2
        else
          log_error "Config file not specified or not found: $2"
          exit 1
        fi
        ;;
      -n|--non-interactive)
        NON_INTERACTIVE=true
        shift
        ;;
      -l|--log-level)
        if [[ -n "$2" ]]; then
          LOG_LEVEL="$2"
          shift 2
        else
          log_error "Log level not specified"
          exit 1
        fi
        ;;
      -t|--server-type)
        if [[ -n "$2" ]]; then
          SERVER_TYPE="$2"
          FORCE_SERVER_TYPE=true
          shift 2
        else
          log_error "Server type not specified"
          exit 1
        fi
        ;;
      --modules)
        if [[ -n "$2" ]]; then
          module_selections="$2"
          NON_INTERACTIVE=true
          log_info "Modules specified via command line: $module_selections"
          shift 2
        else
          log_error "Modules not specified"
          exit 1
        fi
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# Function to display help
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help                  Show this help message"
  echo "  -v, --version               Show version information"
  echo "  -c, --config <file>         Use custom configuration file"
  echo "  -n, --non-interactive       Run in non-interactive mode"
  echo "  -l, --log-level <level>     Set log level (DEBUG, INFO, WARN, ERROR, FATAL)"
  echo "  -t, --server-type <type>    Set server type (VPS1-VPS8, DSCPU1-DSCPU9)"
  echo "  --modules <nums>            Specify modules to run (comma-separated, e.g., 1,3,5)"
  echo ""
  echo "Available modules:"
  for ((i=0; i<${#MODULES[@]}; i++)); do
    echo "  $((i+1)). ${MODULES[$i]}"
  done
}

# Function to select modules to run
select_modules() {
  if [[ "$NON_INTERACTIVE" == "true" && -n "$module_selections" ]]; then
    # Parse module selections from command line arguments
    selected_modules=()
    log_info "Parsing module selections: $module_selections"
    IFS=',' read -ra selections <<< "$module_selections"
    for selection in "${selections[@]}"; do
      if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#MODULES[@]}" ]; then
        selected_modules+=("$((selection-1))")
        log_info "Added module: ${MODULES[$((selection-1))]}"
      else
        log_warn "Invalid module selection: $selection. Ignoring."
      fi
    done
  elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    # Use module flags from config to determine which modules to run
    selected_modules=()
    log_info "Using module flags from configuration"
    for ((i=0; i<${#MODULE_FLAGS[@]}; i++)); do
      flag_value="${!MODULE_FLAGS[$i]}"
      if [[ "$flag_value" == "true" ]]; then
        selected_modules+=("$i")
        log_info "Added module from config: ${MODULES[$i]}"
      fi
    done
  else
    # Interactive selection of modules
    print_section "Module Selection"
    echo "Please select which optimization modules you want to run:"
    echo ""
    
    for ((i=0; i<${#MODULES[@]}; i++)); do
      echo "$((i+1)). ${MODULES[$i]}"
    done
    
    echo ""
    echo "Enter the numbers of the modules you want to run (comma-separated, e.g., 1,3,5 or 'all'):"
    read -r input
    
    # Process selections
    selected_modules=()
    if [[ "${input,,}" == "all" ]]; then
      for ((i=0; i<${#MODULES[@]}; i++)); do
        selected_modules+=("$i")
      done
    else
      # Replace commas with spaces and split
      input=${input//,/ }
      
      # Process selections
      for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#MODULES[@]}" ]; then
          selected_modules+=("$((num-1))")
        else
          print_error "Invalid selection: $num. Ignoring."
        fi
      done
    fi
  fi
  
  # If no modules selected, exit
  if [ ${#selected_modules[@]} -eq 0 ]; then
    log_error "No modules selected. Exiting."
    exit 1
  fi
  
  # Log selected modules
  log_info "Selected modules: ${#selected_modules[@]}"
  for index in "${selected_modules[@]}"; do
    log_info "  - ${MODULES[$index]}"
  done
}

# Function to confirm execution
confirm_execution() {
  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    log_info "Running in non-interactive mode. Skipping confirmation."
    return 0
  fi
  
  print_section "Confirmation"
  echo "The following modules will be executed:"
  echo ""
  
  for index in "${selected_modules[@]}"; do
    echo "  - ${MODULES[$index]}"
  done
  
  echo ""
  if ! ask_yes_no "Do you want to continue?" "y"; then
    log_info "Execution cancelled by user."
    exit 0
  fi
}

# Function to execute selected modules
execute_modules() {
  local total_modules=${#selected_modules[@]}
  local current_module=0
  
  print_header "Executing Optimization Modules"
  log_info "Starting execution of $total_modules modules"
  
  # Create backup directory if it doesn't exist
  if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    log_info "Created backup directory: $BACKUP_DIR"
  fi
  
  # Execute each selected module
  for index in "${selected_modules[@]}"; do
    current_module=$((current_module + 1))
    
    # Get module info
    local module_name="${MODULES[$index]}"
    local module_function="${MODULE_FUNCTIONS[$index]}"
    
    # Display progress
    print_section "Module $current_module/$total_modules: $module_name"
    log_info "Executing module: $module_name (function: $module_function)"
    
    # Execute the module function
    if type "$module_function" &>/dev/null; then
      log_debug "Module function $module_function exists, executing..."
      if "$module_function"; then
        print_success "Module executed successfully: $module_name"
        log_info "Module executed successfully: $module_name"
      else
        print_error "Module execution failed: $module_name"
        log_error "Module execution failed: $module_name"
        
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
          if ! ask_yes_no "Do you want to continue with the next module?" "y"; then
            log_info "Execution stopped by user after module failure."
            exit 1
          fi
        fi
      fi
    else
      print_error "Module function not found: $module_function"
      log_error "Module function not found: $module_function"
    fi
    
    # Show progress bar
    show_progress "$current_module" "$total_modules" "Overall Progress"
  done
  
  print_header "Optimization Complete"
  echo "All selected modules have been executed."
  echo ""
  echo "Please review the log file for details: $LOG_FILE"
}

# Main function
main() {
  # Check if running as root
  check_root
  
  # Load configuration from file
  load_config
  
  # Ensure log directory exists
  local log_dir
  log_dir=$(dirname "$LOG_FILE")
  if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir" 2>/dev/null
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Unable to create log directory at $log_dir"
      exit 1
    fi
  fi
  
  # Initialize logging
  init_logging "$LOG_FILE" "$LOG_LEVEL"
  
  # Parse command-line arguments
  parse_arguments "$@"
  
  # Load modules
  load_modules
  
  # Display banner
  display_banner
  
  # Check OS version
  RELEASE=$(check_os_version)
  log_info "OS Version: $RELEASE"
  
  # Check if cPanel is installed
  check_cpanel
  
  # Auto-detect server type if not specified
  if [[ -z "$SERVER_TYPE" || "$FORCE_SERVER_TYPE" != "true" ]]; then
    SERVER_TYPE=$(detect_server_type)
    log_info "Auto-detected server type: $SERVER_TYPE"
  else
    log_info "Using specified server type: $SERVER_TYPE"
  fi
  
  # Select modules to run
  select_modules
  
  # Confirm execution
  confirm_execution
  
  # Execute selected modules
  execute_modules
  
  log_info "Server optimization completed."
  return 0
}

# Execute main function
main "$@"
exit $?
