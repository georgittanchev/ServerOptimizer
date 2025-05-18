# Server Optimizer Implementation Plan

This document outlines the plan for implementing the remaining modules of the Server Optimizer project.

## Completed Components

- Core structure and directory layout
- Library modules:
  - `lib/logging.sh` - Logging functionality
  - `lib/utils.sh` - Common utility functions
  - `lib/ui.sh` - User interface functions
- Configuration system:
  - `config/default.conf` - Default configuration file
- Core scripts:
  - `optimize.sh` - Main orchestration script
  - `install.sh` - Installation script
- System module:
  - `modules/system.sh` - System limits configuration
- Apache module:
  - `modules/apache.sh` - Apache optimization functions
- MySQL module:
  - `modules/mysql.sh` - MySQL/MariaDB configuration
  - `templates/mysql/*.cnf` - Local MySQL configuration templates
- Redis module:
  - `modules/redis.sh` - Redis installation and configuration
- LSAPI module:
  - `modules/lsapi.sh` - LSAPI installation and configuration
- WordPress module:
  - `modules/wordpress.sh` - WordPress Redis configuration
- cPanel module:
  - `modules/cpanel.sh` - cPanel tweaks and Engintron installation

## Implementation Plan

### Phase 1: Implement Remaining Core Modules

✅ 1. Redis Module (`modules/redis.sh`)
- ✅ Implement `install_configure_redis` function
- ✅ Implement `calculate_redis_memory` function
- ✅ Add proper error handling and logging

✅ 2. LSAPI Module (`modules/lsapi.sh`)
- ✅ Implement `install_mod_lsapi` function
- ✅ Implement `calculate_lsapi_settings` function
- ✅ Add helper functions for LSAPI configuration

### Phase 2: Implement Additional Modules

✅ 3. WordPress Module (`modules/wordpress.sh`)
- ✅ Implement `configure_wordpress_redis` function
- ✅ Add WordPress site detection
- ✅ Add error handling for WordPress configuration

✅ 4. cPanel Module (`modules/cpanel.sh`)
- ✅ Implement `direct_modify_cpanel_tweak_settings` function
- ✅ Implement `install_engintron` function
- ✅ Add proper error handling and logging

✅ 5. Security Module (`modules/security.sh`)
- ✅ Implement `implement_bad_bot_blocker` function
- ✅ Add proper error handling and logging

✅ 6. Swap Module (`modules/swap.sh`)
- ✅ Implement `manage_swap` function
- ✅ Implement `calculate_swap_size` function
- ✅ Add error handling and validation

✅ 7. Imunify Module (`modules/imunify.sh`)
- ✅ Implement `optimize_imunify360` function
- ✅ Add detection of Imunify installation
- ✅ Add proper error handling and logging

### Phase 3: Testing and Documentation

#### Testing
- Test each module individually
- Test the entire system end-to-end
- Test on different cPanel server configurations
- Test error handling and recovery

#### Documentation
- Complete module-specific documentation
- Update main README with any additional details
- Add example configurations
- Add troubleshooting section

## Module Implementation Details

Each module should follow this general structure:

```bash
#!/bin/bash
#
# Module: [Module Name]
# Description: [Module Description]
#
# This module contains functions for [module functionality].

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"

# Helper functions specific to this module

# Main function(s) that will be called from the main script
main_function_name() {
  print_section "User-friendly section title"
  log_info "Starting operation..."
  
  # Check prerequisites
  
  # Backup existing configuration
  
  # Implement the main functionality
  
  # Apply changes
  
  # Verify that changes were applied correctly
  
  log_info "Operation completed successfully."
  print_success "Operation completed successfully."
  
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
  main_function_name
fi
```

## Implementation Guidelines

1. **Function Naming**: Use descriptive names that clearly indicate the function's purpose
2. **Error Handling**: Always check the return value of commands and provide meaningful error messages
3. **Logging**: Use appropriate log levels (debug, info, warn, error, fatal)
4. **User Interface**: Provide clear feedback to the user about what is happening
5. **Configuration**: Use the global configuration variables where appropriate
6. **Backup**: Always backup files before modifying them
7. **Idempotence**: Functions should be safe to run multiple times
8. **Validation**: Validate inputs and server state before making changes
9. **Documentation**: Add inline comments for complex code or logic
10. **Local Resources**: Store templates and resources locally rather than fetching them from external sources when possible

## Code Review Process

1. Implement a module following the structure and guidelines above
2. Test the module independently
3. Review the code for adherence to the Google Shell Style Guide
4. Check for error handling and proper logging
5. Ensure proper use of the utility and UI functions
6. Integrate with the main script
7. Test the integrated solution

## Conclusion

By following this implementation plan, we will systematically complete the Server Optimizer project with a focus on maintainability, reliability, and user experience. 