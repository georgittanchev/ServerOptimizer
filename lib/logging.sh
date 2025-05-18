#!/bin/bash
#
# Logging utility for Server Optimizer
# This library provides logging functions for different levels

# Default log file path
LOG_FILE="/var/log/server-optimizer.log"
LOG_LEVEL="INFO"  # Default log level

# Log levels and their numeric values
declare -A LOG_LEVELS
LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)

# Initialize logging
init_logging() {
  local log_file="${1:-$LOG_FILE}"
  local log_level="${2:-$LOG_LEVEL}"
  
  # Set log file path
  LOG_FILE="$log_file"
  
  # Validate and set log level
  if [[ -n "${LOG_LEVELS[$log_level]}" ]]; then
    LOG_LEVEL="$log_level"
  else
    echo "Invalid log level: $log_level. Using default: INFO" >&2
    LOG_LEVEL="INFO"
  fi
  
  # Create log file if it doesn't exist
  touch "$LOG_FILE" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "Unable to create log file at $LOG_FILE. Using stdout for logging." >&2
    LOG_FILE="/dev/stdout"
  fi
  
  # Log initialization
  log_info "Logging initialized. Level: $LOG_LEVEL, File: $LOG_FILE"
}

# Internal logging function
_log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Only log if the level is at or above the configured level
  if [[ "${LOG_LEVELS[$level]}" -ge "${LOG_LEVELS[$LOG_LEVEL]}" ]]; then
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  fi
}

# Public logging functions
log_debug() {
  _log "DEBUG" "$1"
}

log_info() {
  _log "INFO" "$1"
}

log_warn() {
  _log "WARN" "$1"
}

log_error() {
  _log "ERROR" "$1"
}

log_fatal() {
  _log "FATAL" "$1"
}

# Log an error and exit
log_fatal_exit() {
  local message="$1"
  local exit_code="${2:-1}" # Default exit code is 1
  
  log_fatal "$message"
  exit "$exit_code"
}
