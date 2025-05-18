# Server Optimizer

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](docs/CODE_OF_CONDUCT.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-cPanel%2FWHM-orange.svg)]()
[![Bash](https://img.shields.io/badge/Language-Bash-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen.svg)]()

A comprehensive tool for optimizing cPanel servers for better performance and security.

## Overview

Server Optimizer is a modular script designed to automate the optimization of various components of cPanel servers, including:

- System limits and kernel parameters
- Apache web server
- MySQL/MariaDB database
- Redis cache
- LSAPI for PHP
- WordPress optimization
- Security enhancements
- Swap management
- And more...

This project is motivated by and based on the excellent optimization guidelines provided by Engintron:
- [Apache Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-apache)
- [Database Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-database)
- [OS Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-os)

The script is designed to be highly configurable, extensible, and user-friendly, with both interactive and non-interactive modes.

## Features

- **Modular Design**: Each optimization component is separated into a module that can be run independently.
- **Auto-Detection**: Automatically detects server resources and applies appropriate optimizations.
- **Comprehensive Logging**: Detailed logs help track changes and troubleshoot issues.
- **Configuration System**: Easily customize the behavior of the script through a configuration file.
- **Interactive Mode**: User-friendly interface for selecting which optimizations to apply.
- **Non-Interactive Mode**: Suitable for automation and scripted deployments.
- **Backup System**: Automatically backs up configuration files before making changes.

## Prerequisites

- CentOS/RHEL/CloudLinux 7, 8, or 9
- cPanel/WHM installed
- Root access
- WHM API access (most modules depend on WHM API for proper functionality)

## Installation

### Quick Install

```bash
cd /root
git clone https://github.com/georgittanchev/ServerOptimizer.git
bash server-optimizer/install.sh
```

### Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/georgittanchev/ServerOptimizer.git
   ```

2. Move the files to your preferred location:
   ```bash
   mv server-optimizer /usr/local/
   ```

3. Make the scripts executable:
   ```bash
   chmod +x /usr/local/server-optimizer/optimize.sh
   chmod +x /usr/local/server-optimizer/install.sh
   ```

4. Create a symlink (optional):
   ```bash
   ln -s /usr/local/server-optimizer/optimize.sh /usr/local/bin/server-optimizer
   ```

## Usage

### Interactive Mode

To run the script in interactive mode:

```bash
server-optimizer
```

or

```bash
/usr/local/server-optimizer/optimize.sh
```

Follow the on-screen prompts to select which optimization modules to run.

### Non-Interactive Mode

To run the script in non-interactive mode with all optimizations:

```bash
server-optimizer --non-interactive
```

To run specific modules:

```bash
server-optimizer --non-interactive --modules 1,3,5
```

### Command-Line Options

- `-h, --help`: Show help message
- `-v, --version`: Show version information
- `-c, --config <file>`: Use custom configuration file
- `-n, --non-interactive`: Run in non-interactive mode
- `-l, --log-level <level>`: Set log level (DEBUG, INFO, WARN, ERROR, FATAL)
- `-t, --server-type <type>`: Set server type (VPS1-VPS8, DSCPU1-DSCPU9)
- `--modules <nums>`: Specify modules to run (comma-separated, e.g., 1,3,5)

## Configuration

The default configuration file is located at `/etc/server-optimizer.conf`. You can customize this file to change the default behavior of the script.

Example configuration:

```bash
# General Settings
LOG_LEVEL="INFO"
LOG_FILE="/var/log/server-optimizer.log"
BACKUP_DIR="/root/server-optimizer-backups"
NON_INTERACTIVE=false

# System Settings
DISABLE_IPV6=true
MANAGE_SWAP=true
CONFIGURE_SYSTEM_LIMITS=true

# Web Server Settings
INSTALL_ENGINTRON=true
SWITCH_APACHE_MPM=true
OPTIMIZE_APACHE=true
INSTALL_MOD_LSAPI=true

# Database Settings
OPTIMIZE_MYSQL=true

# Cache Settings
INSTALL_REDIS=true
CONFIGURE_REDIS_WP=true
```

Based on extensive testing, I recommend not installing the Event MPM when using Engintron. They're not directly redundant, but their functional overlap can sometimes be counterproductive depending on your workload. In benchmarking tests using Apache Siege, performance actually degraded when Event MPM was enabled alongside Engintron.

## Available Modules

1. **System Limits**: Configures kernel parameters and system limits for optimal performance.
2. **Apache Optimization**: Optimizes Apache settings for better performance. Less is sometimes more.
3. **MySQL Optimization**: Configures MySQL/MariaDB for optimal performance.
4. **Redis Installation and Configuration**: Installs and configures Redis cache.
5. **Engintron Installation**: Installs Engintron (Nginx for cPanel).
6. **LSAPI Installation and Optimization**: Installs and configures LiteSpeed API from the EA module.
7. **WordPress Redis Configuration**: Configures WordPress to use Redis for caching.
8. **cPanel Tweak Settings**: Optimizes cPanel settings.
9. **Bad Bot Blocker**: Implements protection against bad bots using techniques from the Apache Ultimate Bad Bot Blocker.
10. **Swap Management**: Optimizes swap configuration.
11. **Imunify360 Optimization**: Optimizes Imunify360 settings if installed.
12. **Apache MPM Optimization**: Switches Apache MPM from worker to event.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [cPanel](https://cpanel.net/)
- [Engintron](https://engintron.com/) - Special thanks to the Engintron team and community for their comprehensive optimization guides:
  - [Apache Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-apache)
  - [Database Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-database)
  - [OS Optimization Guide](https://engintron.com/docs/#/pages/optimization-guide-os)
- [Apache Ultimate Bad Bot Blocker](https://github.com/mitchellkrogza/apache-ultimate-bad-bot-blocker) - The Bad Bot Blocker module implementation is based on this excellent project
- [LiteSpeed](https://www.litespeedtech.com/)
- [Redis](https://redis.io/)
- [Apache](https://httpd.apache.org/)
- [MySQL](https://www.mysql.com/)

## Disclaimer

This script makes significant changes to your server configuration. Use it at your own discretion. The script has been thoroughly tested in hosting environments running primarily on WHM/cPanel and has helped reduce server downtimes by more than 60% thanks to the implemented optimizations.

The script is under active development and is not a ready-to-use product. There may be bugs; for example, some values introduced by the LSAPI module are known to not exist in certain versions. Do not run it on outdated systems such as CentOS 6, as it will not work properly. It makes backups of all important files, thus if something stops working, simply revert the changes with mv name.conf{,old} mv name.cnf.bkp name.cnf so you can fix the issues introduced by the script.

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL I BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
