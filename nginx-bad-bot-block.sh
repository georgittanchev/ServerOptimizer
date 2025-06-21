#!/bin/bash

##############################################################################
# Engintron Bad Bot Blocker Installer
# Automatically installs and configures nginx-ultimate-bad-bot-blocker
# for Engintron/cPanel environments
##############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGINX_CONF_DIR="/etc/nginx"
NGINX_BOTS_DIR="/etc/nginx/bots.d"
NGINX_CONF_D_DIR="/etc/nginx/conf.d"
COMMON_HTTP_CONF="/etc/nginx/common_http.conf"
INSTALL_SCRIPT_PATH="/usr/local/sbin/install-ngxblocker"

##############################################################################
# Utility Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_engintron() {
    if [[ ! -f "$COMMON_HTTP_CONF" ]]; then
        log_error "Engintron not detected. This script is designed for Engintron/cPanel environments."
        exit 1
    fi
    log_info "Engintron environment detected"
}

##############################################################################
# Bot Blocker Installation Functions
##############################################################################

download_bot_blocker() {
    log_info "Downloading nginx-ultimate-bad-bot-blocker installation script..."

    if wget -q https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O "$INSTALL_SCRIPT_PATH"; then
        chmod +x "$INSTALL_SCRIPT_PATH"
        log_success "Installation script downloaded and made executable"
    else
        log_error "Failed to download installation script"
        exit 1
    fi
}

install_bot_blocker_files() {
    log_info "Installing bot blocker files..."

    # Run installation
    if "$INSTALL_SCRIPT_PATH" -x; then
        log_success "Bot blocker files installed successfully"
    else
        log_error "Failed to install bot blocker files"
        exit 1
    fi
}

fix_duplicate_directives() {
    log_info "Fixing duplicate nginx directives..."

    local botblocker_settings="$NGINX_CONF_D_DIR/botblocker-nginx-settings.conf"

    if [[ -f "$botblocker_settings" ]]; then
        # Comment out duplicate directives that are already in nginx.conf
        sed -i 's/^server_names_hash_bucket_size/#server_names_hash_bucket_size/' "$botblocker_settings"
        sed -i 's/^server_names_hash_max_size/#server_names_hash_max_size/' "$botblocker_settings"
        log_success "Fixed duplicate directives in botblocker-nginx-settings.conf"
    fi
}

##############################################################################
# Server Information Functions
##############################################################################

get_server_ips() {
    log_info "Getting server IP addresses..."

    # Get all server IPs excluding localhost
    local ips=$(ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1)

    if [[ -n "$ips" ]]; then
        log_success "Found server IPs: $(echo $ips | tr '\n' ' ')"
        echo "$ips"
    else
        log_warning "No server IPs found"
        return 1
    fi
}

get_server_domains() {
    log_info "Getting server domains from WHM..."

    # Check if whmapi1 is available
    if ! command -v whmapi1 &> /dev/null; then
        log_warning "whmapi1 not found. Skipping domain whitelist."
        return 1
    fi

    # Get unique domains
    local domains=$(whmapi1 get_domain_info 2>/dev/null | grep domain | grep -v "domain_type" | cut -d':' -f2 | sed 's/^ *//' | grep -v "get_domain_info" | sort | uniq)

    if [[ -n "$domains" ]]; then
        local domain_count=$(echo "$domains" | wc -l)
        log_success "Found $domain_count unique domains"
        echo "$domains"
    else
        log_warning "No domains found"
        return 1
    fi
}

##############################################################################
# Whitelist Configuration Functions
##############################################################################

update_ip_whitelist() {
    local ips="$1"
    local whitelist_file="$NGINX_BOTS_DIR/whitelist-ips.conf"

    if [[ -z "$ips" ]]; then
        log_warning "No IPs to whitelist"
        return 0
    fi

    log_info "Updating IP whitelist..."

    # Create backup
    cp "$whitelist_file" "$whitelist_file.bak"

    # Add server IPs to whitelist
    local ip_section=""
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && ip_section+="\t$ip\t\t0;\n"
    done <<< "$ips"

    # Insert server IPs after the "MY WHITELIST" section
    sed -i "/# MY WHITELIST/,/^$/c\\
# ------------\\
# MY WHITELIST\\
# ------------\\
\\
# Server IPs\\
$ip_section\\
" "$whitelist_file"

    log_success "IP whitelist updated with server IPs"
}

update_domain_whitelist() {
    local domains="$1"
    local whitelist_file="$NGINX_BOTS_DIR/whitelist-domains.conf"

    if [[ -z "$domains" ]]; then
        log_warning "No domains to whitelist"
        return 0
    fi

    log_info "Updating domain whitelist..."

    # Create backup
    cp "$whitelist_file" "$whitelist_file.bak"

    # Escape domains for regex and create whitelist entries
    local domain_section=""
    while IFS= read -r domain; do
        if [[ -n "$domain" ]]; then
            # Escape dots and hyphens for regex
            local escaped_domain=$(echo "$domain" | sed 's/\./\\./g' | sed 's/-/\\-/g')
            domain_section+="\t\"~*(?:\\b)$escaped_domain(?:\\b)\" \t\t\t\t\t\t0;\n"
        fi
    done <<< "$domains"

    # Insert server domains after the "MY WHITELIST" section
    sed -i "/# MY WHITELIST/,/^$/c\\
# ------------\\
# MY WHITELIST\\
# ------------\\
\\
# Server domains\\
$domain_section\\
" "$whitelist_file"

    log_success "Domain whitelist updated with server domains"
}

##############################################################################
# Nginx Configuration Functions
##############################################################################

configure_engintron_includes() {
    log_info "Configuring Engintron includes..."

    # Check if bot blocker includes are already in common_http.conf
    if grep -q "blockbots.conf" "$COMMON_HTTP_CONF"; then
        log_info "Bot blocker includes already present in common_http.conf"
        return 0
    fi

    # Create backup
    cp "$COMMON_HTTP_CONF" "$COMMON_HTTP_CONF.bak"

    # Add bot blocker includes after custom_rules include
    sed -i '/include custom_rules;/a\\n# Include bot blocker rules\ninclude /etc/nginx/bots.d/blockbots.conf;\ninclude /etc/nginx/bots.d/ddos.conf;' "$COMMON_HTTP_CONF"

    log_success "Added bot blocker includes to common_http.conf"
}

test_nginx_config() {
    log_info "Testing nginx configuration..."

    if nginx -t 2>/dev/null; then
        log_success "Nginx configuration test passed"
        return 0
    else
        log_error "Nginx configuration test failed"
        nginx -t
        return 1
    fi
}

reload_nginx() {
    log_info "Reloading nginx..."

    if nginx -s reload 2>/dev/null; then
        log_success "Nginx reloaded successfully"
        return 0
    else
        log_error "Failed to reload nginx"
        return 1
    fi
}

##############################################################################
# Main Installation Function
##############################################################################

install_engintron_bad_bot_blocker() {
    log_info "Starting Engintron Bad Bot Blocker installation..."
    echo "=============================================="

    # Pre-flight checks
    check_root
    check_engintron

    # Download and install bot blocker
    download_bot_blocker
    install_bot_blocker_files
    fix_duplicate_directives

    # Get server information
    local server_ips=$(get_server_ips)
    local server_domains=$(get_server_domains)

    # Update whitelists
    update_ip_whitelist "$server_ips"
    update_domain_whitelist "$server_domains"

    # Configure nginx
    configure_engintron_includes

    # Test and reload
    if test_nginx_config; then
        reload_nginx
        echo "=============================================="
        log_success "Engintron Bad Bot Blocker installation completed successfully!"
        log_info "Your server IPs and domains have been automatically whitelisted"
        log_info "The bot blocker is now active and protecting your server"
    else
        echo "=============================================="
        log_error "Installation completed but nginx configuration has errors"
        log_error "Please check the nginx configuration manually"
        exit 1
    fi
}

##############################################################################
# Update Function
##############################################################################

update_bad_bot_blocker() {
    log_info "Updating bad bot blocker..."

    if [[ -f "/usr/local/sbin/update-ngxblocker" ]]; then
        /usr/local/sbin/update-ngxblocker

        # Re-update whitelists after update
        local server_ips=$(get_server_ips)
        local server_domains=$(get_server_domains)
        update_ip_whitelist "$server_ips"
        update_domain_whitelist "$server_domains"

        if test_nginx_config; then
            reload_nginx
            log_success "Bad bot blocker updated successfully"
        else
            log_error "Update completed but nginx configuration has errors"
        fi
    else
        log_error "Update script not found. Please run installation first."
    fi
}

##############################################################################
# Help Function
##############################################################################

show_help() {
    echo "Engintron Bad Bot Blocker Installer"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  install    Install and configure nginx-ultimate-bad-bot-blocker for Engintron"
    echo "  update     Update existing bad bot blocker installation"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install    # Install bad bot blocker"
    echo "  $0 update     # Update bad bot blocker"
    echo ""
}

##############################################################################
# Main Script Logic
##############################################################################

case "${1:-install}" in
    "install")
        install_engintron_bad_bot_blocker
        ;;
    "update")
        update_bad_bot_blocker
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac