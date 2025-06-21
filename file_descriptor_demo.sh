#!/bin/bash
#
# File Descriptor Exhaustion Demo
# Shows how high file descriptor limits can cause problems
#

echo "=== File Descriptor Exhaustion Demo ==="
echo ""

# Show current limits
echo "1. CURRENT SYSTEM LIMITS:"
echo "System-wide file-max: $(cat /proc/sys/fs/file-max)"
echo "Per-process nr_open: $(cat /proc/sys/fs/nr_open)"
echo "Current process ulimit: $(ulimit -n)"
echo ""

# Show current usage
echo "2. CURRENT USAGE:"
total_open=$(lsof 2>/dev/null | wc -l)
echo "Total open file descriptors: $total_open"
echo "Available file descriptors: $(($(cat /proc/sys/fs/file-max) - total_open))"
echo ""

# Show memory impact
echo "3. MEMORY IMPACT CALCULATION:"
echo "Estimated kernel memory for file descriptors:"
echo "  Current usage: ~$((total_open / 1024)) MB"
echo "  If maxed out: ~$(($(cat /proc/sys/fs/file-max) / 1024 / 1024)) GB"
echo ""

# Show what happens during high load
echo "4. HIGH LOAD SCENARIO SIMULATION:"
echo "If your Apache configuration allows:"

# Get Apache settings if available
if [ -f /etc/cpanel/ea4/ea4.conf ]; then
    maxclients=$(grep -o '"maxclients":[0-9]*' /etc/cpanel/ea4/ea4.conf 2>/dev/null | cut -d: -f2 || echo "150")
    serverlimit=$(grep -o '"serverlimit":[0-9]*' /etc/cpanel/ea4/ea4.conf 2>/dev/null | cut -d: -f2 || echo "180")
else
    maxclients=150
    serverlimit=180
fi

echo "  MaxClients: $maxclients"
echo "  ServerLimit: $serverlimit"
echo ""

# Calculate potential file descriptor usage
echo "5. POTENTIAL FILE DESCRIPTOR USAGE:"
echo "Conservative estimate per Apache process: 50 file descriptors"
echo "High load estimate per Apache process: 200 file descriptors"
echo ""
echo "Conservative scenario:"
echo "  $serverlimit processes × 50 FDs = $((serverlimit * 50)) file descriptors"
echo ""
echo "High load scenario:"
echo "  $serverlimit processes × 200 FDs = $((serverlimit * 200)) file descriptors"
echo "  Plus system processes: ~2,000 FDs"
echo "  Total: ~$((serverlimit * 200 + 2000)) file descriptors"
echo ""

# Show when problems occur
echo "6. WHEN 507 ERRORS OCCUR:"
echo ""
echo "🔴 PROBLEM SCENARIOS:"
echo "  A) Kernel runs out of memory for file descriptor tables"
echo "  B) Process hits ulimit -n (per-process limit)"
echo "  C) System hits fs.file-max (system-wide limit)"
echo "  D) Inode table exhaustion (filesystem level)"
echo ""

echo "🔍 SPECIFIC CAUSES:"
echo "  • High traffic websites with many concurrent connections"
echo "  • Applications that don't close file descriptors properly (memory leaks)"
echo "  • Database connections that stay open"
echo "  • Log files being opened repeatedly"
echo "  • Temporary files not being cleaned up"
echo "  • Network sockets remaining in TIME_WAIT state"
echo ""

echo "⚠️  WHY YOUR SCRIPT'S SETTINGS ARE RISKY:"
echo "  • fs.file-max = RAM/2 can be MILLIONS of file descriptors"
echo "  • fs.nr_open = 999,999 allows processes to consume massive resources"
echo "  • No protection against runaway processes"
echo "  • Can exhaust kernel memory before hitting limits"
echo ""

echo "7. REAL-WORLD EXAMPLE:"
echo ""
echo "Scenario: Busy WordPress site with your optimizations"
echo "  • Apache processes: $serverlimit"
echo "  • Each handling: 50 concurrent connections"
echo "  • Plus: Database connections, log files, temp files"
echo "  • Result: Each process uses 100-300 file descriptors"
echo "  • Total: $((serverlimit * 250)) file descriptors"
echo "  • Kernel memory: ~$((serverlimit * 250 / 1024)) MB just for FD tables"
echo ""

echo "8. HOW TO CHECK IF THIS IS YOUR PROBLEM:"
echo ""
echo "Run these commands when experiencing 507 errors:"
echo ""
echo "# Check current file descriptor usage"
echo "lsof | wc -l"
echo ""
echo "# Check per-process usage"
echo "for pid in \$(pgrep httpd); do"
echo "  echo \"PID \$pid: \$(ls /proc/\$pid/fd 2>/dev/null | wc -l) file descriptors\""
echo "done"
echo ""
echo "# Check for file descriptor exhaustion errors"
echo "grep -i \"too many open files\" /var/log/messages"
echo "grep -i \"cannot allocate memory\" /var/log/httpd/error_log"
echo ""
echo "# Check kernel memory usage"
echo "cat /proc/meminfo | grep -E \"Slab|KernelStack\""
echo ""

echo "9. SAFER LIMITS:"
echo ""
echo "Instead of your current settings:"
echo "  fs.file-max = $(($(cat /proc/sys/fs/file-max)))  # Current"
echo "  fs.nr_open = $(cat /proc/sys/fs/nr_open)   # Current"
echo ""
echo "Consider more conservative values:"
echo "  fs.file-max = 1048576    # 1 million (still high but safer)"
echo "  fs.nr_open = 65536       # 64K per process (more reasonable)"
echo ""
echo "This still allows high performance but prevents system exhaustion." 