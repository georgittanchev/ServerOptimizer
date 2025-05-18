# Contributing to Server Optimizer

Thank you for your interest in contributing to Server Optimizer! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to see if the problem has already been reported. If it has and the issue is still open, add a comment to the existing issue instead of opening a new one.

When creating a bug report, please include as many details as possible:

- Use a clear and descriptive title
- Describe the exact steps to reproduce the problem
- Provide specific examples of the steps
- Describe the behavior you observed and what behavior you expected to see
- Include server details (OS version, cPanel version, etc.)
- Include logs if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- A clear and descriptive title
- A detailed description of the proposed functionality
- Explain why this enhancement would be useful to most users
- Provide examples of how this enhancement would be used

### Pull Requests

- Fill in the required template
- Do not include issue numbers in the PR title
- Include screenshots and animated GIFs in your pull request whenever possible
- Follow the [Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Include comments in your code where necessary
- End all files with a newline
- Avoid platform-dependent code

## Styleguides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- Consider starting the commit message with an applicable emoji:
  - 🎨 `:art:` when improving the format/structure of the code
  - 🐎 `:racehorse:` when improving performance
  - 🚱 `:non-potable_water:` when plugging memory leaks
  - 📝 `:memo:` when writing docs
  - 🐧 `:penguin:` when fixing something on Linux
  - 💥 `:boom:` when fixing a crash
  - 🔒 `:lock:` when dealing with security

### Shell Scripting Styleguide

- Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use 2 spaces for indentation
- Use `[[ ... ]]` for conditional testing
- Use `$()` for command substitution
- Use `${var}` for variable substitution
- Use `local` to declare local variables in functions
- Add comments to explain complex code or why (not what) the code is doing something
- Use meaningful variable and function names
- Use lowercase for variable names with underscores to separate words
- Use UPPERCASE for constants and environment variables

## Adding a New Module

To add a new module to Server Optimizer:

1. Create a new script file in the `modules/` directory
2. Implement the core functionality in a main function
3. Add proper error handling
4. Add documentation for the module in `docs/module-specific-docs/`
5. Update the main script to include your module
6. Add configuration options to `config/default.conf` if needed
7. Test your module thoroughly

Example module structure:

```bash
#!/bin/bash
#
# Module: Example Module
# Description: An example module for the Server Optimizer
#
# This module demonstrates how to create a new module
# for the Server Optimizer project.

# Source required libraries (if needed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utils.sh"

# Main function for this module
example_module_main() {
  log_info "Starting example module"
  
  # Check prerequisites
  command -v example_command >/dev/null 2>&1 || {
    log_error "Required command 'example_command' not found"
    return 1
  }
  
  # Implement your functionality here
  
  log_info "Example module completed successfully"
  return 0
}

# Execute this if the script is run directly (for testing)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  example_module_main "$@"
fi
```

## Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests if available
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Community

Discussions about Server Optimizer take place on this repository's [Issues](https://github.com/georgittanchev/server-optimizer/issues) and [Pull Requests](https://github.com/georgittanchev/server-optimizer/pulls) sections.

Thank you for contributing to Server Optimizer!
