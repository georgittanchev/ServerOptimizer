#!/bin/bash
#
# Path Testing Script for Server Optimizer
# This script verifies that all paths are correctly configured

INSTALL_DIR="/usr/local/server-optimizer"
SYMLINK="/usr/local/bin/server-optimizer"

echo "====================================="
echo "  Server Optimizer Path Tester"
echo "====================================="
echo ""

# Check if installation directory exists
echo "Checking installation directory..."
if [[ -d "$INSTALL_DIR" ]]; then
  echo "✓ Installation directory exists: $INSTALL_DIR"
else
  echo "✗ Installation directory does not exist: $INSTALL_DIR"
  exit 1
fi

# Check symlink
echo -e "\nChecking symlink..."
if [[ -L "$SYMLINK" ]]; then
  echo "✓ Symlink exists: $SYMLINK"
  
  # Verify symlink target
  link_target=$(readlink -f "$SYMLINK")
  echo "  Target: $link_target"
  
  if [[ "$link_target" == "$INSTALL_DIR/optimize.sh" ]]; then
    echo "  ✓ Symlink points to correct target"
  else
    echo "  ✗ Symlink points to incorrect target"
    echo "    Expected: $INSTALL_DIR/optimize.sh"
  fi
else
  echo "✗ Symlink does not exist: $SYMLINK"
fi

# Check for required libraries
echo -e "\nChecking required libraries..."
libs=("logging.sh" "utils.sh" "ui.sh")
for lib in "${libs[@]}"; do
  lib_path="$INSTALL_DIR/lib/$lib"
  if [[ -f "$lib_path" ]]; then
    echo "✓ Library found: $lib_path"
  else
    echo "✗ Library not found: $lib_path"
  fi
done

# Check for main script
echo -e "\nChecking main script..."
if [[ -f "$INSTALL_DIR/optimize.sh" ]]; then
  echo "✓ Main script found: $INSTALL_DIR/optimize.sh"
  if [[ -x "$INSTALL_DIR/optimize.sh" ]]; then
    echo "  ✓ Script is executable"
  else
    echo "  ✗ Script is not executable"
  fi
else
  echo "✗ Main script not found: $INSTALL_DIR/optimize.sh"
fi

# Check directory structure
echo -e "\nVerifying directory structure..."
dirs=("lib" "modules" "templates" "config" "docs")
for dir in "${dirs[@]}"; do
  dir_path="$INSTALL_DIR/$dir"
  if [[ -d "$dir_path" ]]; then
    echo "✓ Directory found: $dir_path"
  else
    echo "✗ Directory not found: $dir_path"
  fi
done

echo -e "\nTest complete. Fix any issues reported above."
exit 0 