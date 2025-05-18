#!/bin/bash
#
# UI functions for Server Optimizer
# This library provides user interface functions

# Source other libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=logging.sh
source "$SCRIPT_DIR/logging.sh"

# Default terminal width (if detected width is unreasonable)
DEFAULT_WIDTH=80

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get terminal width
get_terminal_width() {
  local width
  
  # Try to get the terminal width
  if command -v tput &>/dev/null; then
    width=$(tput cols)
  else
    width=$(stty size 2>/dev/null | awk '{print $2}')
  fi
  
  # If width is not a number or is too small, use default
  if ! [[ "$width" =~ ^[0-9]+$ ]] || [ "$width" -lt 40 ]; then
    width=$DEFAULT_WIDTH
  fi
  
  echo "$width"
}

# Print a header
print_header() {
  local title="$1"
  local width
  width=$(get_terminal_width)
  local padding=$(( (width - ${#title} - 4) / 2 ))
  
  if [ "$padding" -lt 1 ]; then
    padding=1
  fi
  
  local line
  line=$(printf "%*s" "$width" | tr ' ' '=')
  
  echo ""
  echo "$line"
  printf "%*s %s %*s\n" "$padding" "" "$title" "$padding" ""
  echo "$line"
  echo ""
}

# Print a section header
print_section() {
  local section="$1"
  local width
  width=$(get_terminal_width)
  
  echo ""
  echo -e "${BLUE}## $section ##${NC}"
  printf "%*s\n" "$width" | tr ' ' '-'
  echo ""
}

# Print a message with color
print_message() {
  local message="$1"
  local color="${2:-$NC}"
  
  echo -e "${color}${message}${NC}"
}

# Print success message
print_success() {
  print_message "$1" "$GREEN"
}

# Print error message
print_error() {
  print_message "$1" "$RED"
}

# Print warning message
print_warning() {
  print_message "$1" "$YELLOW"
}

# Print info message
print_info() {
  print_message "$1" "$BLUE"
}

# Show progress
show_progress() {
  local current="$1"
  local total="$2"
  local prefix="${3:-Progress:}"
  local width
  width=$(get_terminal_width)
  local bar_width=$((width - ${#prefix} - 10))
  
  if [ "$bar_width" -lt 10 ]; then
    bar_width=10
  fi
  
  local percent=$((current * 100 / total))
  local completed=$((current * bar_width / total))
  local remaining=$((bar_width - completed))
  
  printf "\r%s [%s%s] %3d%%" \
    "$prefix" \
    "$(printf "%*s" "$completed" | tr ' ' '=')" \
    "$(printf "%*s" "$remaining" | tr ' ' ' ')" \
    "$percent"
  
  if [ "$current" -eq "$total" ]; then
    echo ""
  fi
}

# Display menu and get user selection
display_menu() {
  local title="$1"
  shift
  local options=("$@")
  local num_options=${#options[@]}
  
  print_section "$title"
  
  for ((i=0; i<num_options; i++)); do
    echo "$((i+1))) ${options[$i]}"
  done
  
  echo ""
  local selection
  read -rp "Enter your choice (1-$num_options): " selection
  
  # Validate selection
  if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$num_options" ]; then
    print_error "Invalid selection. Please enter a number between 1 and $num_options."
    return 1
  fi
  
  # Return the selection (1-based)
  return "$selection"
}

# Display a multi-select menu and get user selections
display_multiselect_menu() {
  local title="$1"
  shift
  local options=("$@")
  local num_options=${#options[@]}
  local selections=()
  
  print_section "$title"
  
  echo "Select options (comma-separated or space-separated):"
  for ((i=0; i<num_options; i++)); do
    echo "$((i+1))) ${options[$i]}"
  done
  
  echo ""
  local input
  read -rp "Enter your choices (1-$num_options, ex: 1,3,5 or '1 3 5' or 'all'): " input
  
  # Handle 'all' option
  if [[ "${input,,}" == "all" ]]; then
    for ((i=1; i<=num_options; i++)); do
      selections+=("$i")
    done
    echo "${selections[*]}"
    return 0
  fi
  
  # Replace commas with spaces and split
  input=${input//,/ }
  
  # Process selections
  for num in $input; do
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$num_options" ]; then
      selections+=("$num")
    else
      print_error "Invalid selection: $num. Ignoring."
    fi
  done
  
  # If no valid selections, return error
  if [ ${#selections[@]} -eq 0 ]; then
    print_error "No valid selections made."
    return 1
  fi
  
  # Return the selections as a space-separated list
  echo "${selections[*]}"
  return 0
}
