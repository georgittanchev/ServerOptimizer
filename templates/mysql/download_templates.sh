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
  ["VPS1"]="https://gist.githubusercontent.com/georgittanchev/0949f1c2a411cb925105a62b14e12069/raw/354c5e7c99cae16733125d062be75b30476a440e/VPS1MySQL.txt"
  ["VPS2"]="https://gist.githubusercontent.com/georgittanchev/01f88dd2972f0d871ec563a307e95ec8/raw/d77d6e2e8afc18c211c82148b6fa2160fbe785b5/VPS2MySQL.txt"
  ["VPS3"]="https://gist.githubusercontent.com/georgittanchev/bfa58b46b7845ed67383300d466630f6/raw/3d8f000dda89371f2826ea52638204f4f0a930f4/VPS3MySQL.txt"
  ["VPS4"]="https://gist.githubusercontent.com/georgittanchev/b400891aea0fb7418ef5adecd669079c/raw/6a7b501b78db4de0d5394fad490518910b56ff4f/VPS4MySQL.txt"
  ["VPS5"]="https://gist.githubusercontent.com/georgittanchev/53a68fde4969bf5d2f3318404b757b59/raw/d4e9d9360dfa3368b1f875ee99c40f59ddaead15/VPS5MySQL.txt"
  ["DSCPU1"]="https://gist.githubusercontent.com/georgittanchev/0b3efaa6d599d63953b111066df03419/raw/0aadc2ac15889d850f69b747944f15ad41b238ea/DSCPU1MySQL.txt"
  ["DSCPU2"]="https://gist.githubusercontent.com/georgittanchev/7d98d948bb9523abfb96c69fd2175b1b/raw/a900582d159bcc92cccf76d441fc303dd40f9d32/DSCPU2MySQL.txt"
  ["DSCPU3"]="https://gist.githubusercontent.com/georgittanchev/b18a187fe8a1b7bfef0fc4aaa6466ae1/raw/a72392dd19707a312b03a6d1bb4aace917c80268/DSCPU3MySQL.txt"
  ["DSCPU4"]="https://gist.githubusercontent.com/georgittanchev/a10140a9ab6aabc2576a29333c52f8a4/raw/467135210ac0737c979cc6f39cf509ee15074a80/DSCPU4MySQL.txt"
  ["DSCPU5"]="https://gist.githubusercontent.com/georgittanchev/05a041027ba56aee686bd61a1bb8be03/raw/230d45f2ec29ef70e5d82947533839e82e622766/DSCPU5MySQL.txt"
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