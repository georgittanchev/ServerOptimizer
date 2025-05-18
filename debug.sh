#!/bin/bash

# First, source the module
echo "Sourcing system.sh"
source ./modules/system.sh

# Test if functions are available
echo "Testing function availability:"
declare -F | grep configure_system_limits
declare -F | grep optimize_apache

# Try sourcing other module
echo "Sourcing apache.sh"
source ./modules/apache.sh

# Test if functions are available
echo "Testing function availability again:"
declare -F | grep configure_system_limits
declare -F | grep optimize_apache_settings

# Try sourcing LSAPI module
echo "Sourcing lsapi.sh"
source ./modules/lsapi.sh

# Test LSAPI function
echo "Testing LSAPI function availability:"
declare -F | grep install_mod_lsapi

# Now try running the LSAPI module
echo "Now trying to run the optimization script with module 6"
bash optimize.sh --modules 6 