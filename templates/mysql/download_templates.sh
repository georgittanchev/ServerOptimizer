#!/bin/bash
#
# MySQL Templates Downloader
# Downloads MySQL configuration templates for different server types
#

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Downloading MySQL configuration templates..."

# Define template URLs
declare -A TEMPLATE_URLS
TEMPLATE_URLS=(
  ["VPS1"]="https://gist.githubusercontent.com/georgittanchev/0949f1c2a411cb925105a62b14e12069/raw/f8b7d3dd2842584110d3dc5f8e3fa8ff3b796985/VPS1MySQL.txt"
  ["VPS2"]="https://gist.githubusercontent.com/georgittanchev/01f88dd2972f0d871ec563a307e95ec8/raw/716fcd1a5013631dd221744dd05fdcef7ebe30ed/VPS2MySQL.txt"
  ["VPS3"]="https://gist.githubusercontent.com/georgittanchev/bfa58b46b7845ed67383300d466630f6/raw/cc34dcde8d12ce67c663524140cc7bd98d0f17ef/VPS3MySQL.txt"
  ["VPS4"]="https://gist.githubusercontent.com/georgittanchev/b400891aea0fb7418ef5adecd669079c/raw/efa83eb04fa1661b981bb39628c7fe9b0996d802/VPS4MySQL.txt"
  ["VPS5"]="https://gist.githubusercontent.com/georgittanchev/53a68fde4969bf5d2f3318404b757b59/raw/a7e391808df86e7331ea5f3a2c66132c1a097417/VPS5MySQL.txt"
  ["DSCPU1"]="https://gist.githubusercontent.com/georgittanchev/0b3efaa6d599d63953b111066df03419/raw/6b01bb6b06c158d3798a761c6138163d712475ca/DSCPU1MySQL.txt"
  ["DSCPU2"]="https://gist.githubusercontent.com/georgittanchev/7d98d948bb9523abfb96c69fd2175b1b/raw/8b3b6c6e3b8e7342d29fc049311d5434bc7099f5/DSCPU2MySQL.txt"
  ["DSCPU3"]="https://gist.githubusercontent.com/georgittanchev/b18a187fe8a1b7bfef0fc4aaa6466ae1/raw/0a7300d6a29ca41b967840081aa26bb9f5ad0beb/DSCPU3MySQL.txt"
  ["DSCPU4"]="https://gist.githubusercontent.com/georgittanchev/a10140a9ab6aabc2576a29333c52f8a4/raw/010a3dc4297d747759c0e894f422b300b1db9768/DSCPU4MySQL.txt"
  ["DSCPU5"]="https://gist.githubusercontent.com/georgittanchev/05a041027ba56aee686bd61a1bb8be03/raw/5282fb8e168e1acdbea71002b8e260db3388a1df/DSCPU5MySQL.txt"
)

# Download each template
success_count=0
failure_count=0

for type in "${!TEMPLATE_URLS[@]}"; do
  url=${TEMPLATE_URLS[$type]}
  output_file="${SCRIPT_DIR}/${type}.cnf"
  
  echo "Downloading template for ${type}..."
  if wget -q -O "$output_file" "$url"; then
    echo "  ✓ Downloaded $type template"
    ((success_count++))
  else
    echo "  ✗ Failed to download $type template"
    ((failure_count++))
  fi
done

# Summary
echo ""
echo "Download summary:"
echo "  ✓ Successfully downloaded $success_count templates"
if [[ $failure_count -gt 0 ]]; then
  echo "  ✗ Failed to download $failure_count templates"
  exit 1
else
  echo "All templates downloaded successfully!"
  exit 0
fi 