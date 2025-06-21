#!/bin/bash
#
# Server Optimizer Installer
# This script installs the Server Optimizer tool

VERSION="1.0.0"
INSTALL_DIR="/usr/local/server-optimizer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Create banner
echo "====================================="
echo "  Server Optimizer Installer v${VERSION}"
echo "====================================="
echo ""

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
  echo "Server Optimizer is already installed at $INSTALL_DIR"
  echo "Would you like to update it? (y/n)"
  read -r answer
  if [[ "${answer,,}" != "y" ]]; then
    echo "Installation cancelled."
    exit 0
  fi
  
  # Backup existing installation
  backup_dir="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing installation to $backup_dir"
  cp -r "$INSTALL_DIR" "$backup_dir" || {
    echo "Failed to backup existing installation"
    exit 1
  }
fi

# Create installation directory
echo "Installing Server Optimizer to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" || {
  echo "Failed to create installation directory"
  exit 1
}

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$INSTALL_DIR/templates/mysql"
mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/modules"
mkdir -p "$INSTALL_DIR/config"
mkdir -p "$INSTALL_DIR/docs"
mkdir -p "$INSTALL_DIR/backups"

# Debug directory structure
echo "Directory structure created:"
find "$INSTALL_DIR" -type d | sort

# Copy files
echo "Copying files..."
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR" || {
  echo "Failed to copy files"
  exit 1
}

# Remove any existing symlink
if [[ -L "/usr/local/bin/server-optimizer" ]]; then
  echo "Removing existing symlink..."
  rm -f "/usr/local/bin/server-optimizer"
fi

# Create symlink
echo "Creating symlink..."
ln -sf "$INSTALL_DIR/optimize.sh" /usr/local/bin/server-optimizer || {
  echo "Failed to create symlink"
  exit 1
}

# Verify symlink
echo "Verifying symlink..."
if [[ -L "/usr/local/bin/server-optimizer" ]]; then
  link_target=$(readlink -f "/usr/local/bin/server-optimizer")
  echo "Symlink target: $link_target"
  if [[ "$link_target" == "$INSTALL_DIR/optimize.sh" ]]; then
    echo "Symlink is correctly configured"
  else
    echo "Warning: Symlink points to unexpected location: $link_target"
    echo "Expected: $INSTALL_DIR/optimize.sh"
  fi
else
  echo "Warning: Symlink creation failed"
fi

# Set permissions
echo "Setting permissions..."
chmod +x "$INSTALL_DIR/optimize.sh"
chmod +x "$INSTALL_DIR/install.sh"
find "$INSTALL_DIR/modules" -name "*.sh" -exec chmod +x {} \;
find "$INSTALL_DIR/templates" -name "*.sh" -exec chmod +x {} \;
find "$INSTALL_DIR/lib" -name "*.sh" -exec chmod +x {} \;

# Create log directory
mkdir -p /var/log/server-optimizer
chmod 755 /var/log/server-optimizer

# Ensure logging.sh has the log_success function
echo "Verifying logging functions..."
LOGGING_FILE="$INSTALL_DIR/lib/logging.sh"
if [ -f "$LOGGING_FILE" ]; then
  if ! grep -q "log_success()" "$LOGGING_FILE"; then
    echo "Adding log_success function to logging.sh..."
    # Add SUCCESS to log levels if not present
    if ! grep -q "\[SUCCESS\]" "$LOGGING_FILE"; then
      sed -i 's/LOG_LEVELS=(\[DEBUG\]=0 \[INFO\]=1 \[WARN\]=2 \[ERROR\]=3 \[FATAL\]=4)/LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4 [SUCCESS]=1)/' "$LOGGING_FILE"
    fi
    
    # Add log_success function before log_fatal_exit
    if grep -q "log_fatal_exit()" "$LOGGING_FILE"; then
      sed -i '/log_fatal_exit()/i\
# Log a success message\
log_success() {\
  _log "SUCCESS" "$1"\
}\
' "$LOGGING_FILE"
    else
      # If log_fatal_exit not found, add after log_fatal
      sed -i '/log_fatal()/a\
\
# Log a success message\
log_success() {\
  _log "SUCCESS" "$1"\
}\
' "$LOGGING_FILE"
    fi
    echo "  ✓ log_success function added"
  else
    echo "  ✓ log_success function exists"
  fi
else
  echo "  ✗ logging.sh not found!"
fi

# Handle MySQL templates
TEMPLATE_DIR="$INSTALL_DIR/templates/mysql"

# Check if MySQL templates exist and download if necessary
if [ -f "$TEMPLATE_DIR/download_templates.sh" ]; then
  echo "Downloading MySQL templates..."
  
  # Make template download script executable
  chmod +x "$TEMPLATE_DIR/download_templates.sh"
  
  # Run the download script
  bash "$TEMPLATE_DIR/download_templates.sh" || {
    echo "Warning: Failed to download MySQL templates. You can run the script manually later:"
    echo "  $TEMPLATE_DIR/download_templates.sh"
  }
else
  echo "Warning: Template download script not found. Please download MySQL templates manually."
fi

# Create default configuration if needed
if [[ ! -f "/etc/server-optimizer.conf" ]]; then
  echo "Creating default configuration..."
  
  if [[ -f "$INSTALL_DIR/config/default.conf" ]]; then
    cp "$INSTALL_DIR/config/default.conf" /etc/server-optimizer.conf || {
      echo "Failed to create configuration file"
      exit 1
    }
  else
    echo "Warning: Default configuration not found."
    # Create a minimal configuration
    cat > /etc/server-optimizer.conf << EOF
# Server Optimizer Configuration
LOG_LEVEL="INFO"
LOG_FILE="/var/log/server-optimizer/server-optimizer.log"
BACKUP_DIR="/var/backups/server-optimizer"
SERVER_TYPE="auto"
EOF
  fi
fi

# Verify installation
echo ""
echo "Verifying installation..."
echo "Checking for required libraries..."
for lib in logging.sh utils.sh ui.sh; do
  if [[ -f "$INSTALL_DIR/lib/$lib" ]]; then
    echo "  ✓ $lib found"
  else
    echo "  ✗ $lib missing!"
  fi
done

echo ""
echo "Installation complete!"
echo "You can now run 'server-optimizer' to start the optimizer."
echo "Configuration file: /etc/server-optimizer.conf"
echo "Log file: /var/log/server-optimizer/server-optimizer.log"
echo ""
echo "Note: It is recommended to review the configuration file before running the optimizer."
echo ""

# Ask if user wants to run now
echo "Would you like to run the optimizer now? (y/n)"
read -r answer
if [[ "${answer,,}" == "y" ]]; then
  "$INSTALL_DIR/optimize.sh"
fi

exit 0
