#!/bin/bash
#
# 507 Insufficient Storage Diagnostic Script
# Checks various system limits that could cause 507 errors
#

echo "=== 507 Insufficient Storage Diagnostic ==="
echo "Checking system limits that could cause 507 errors..."
echo ""

# Check disk space
echo "1. DISK SPACE:"
df -h | head -1
df -h | grep -E "/$|/var|/tmp|/home" | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        echo "⚠️  $line (HIGH USAGE)"
    else
        echo "✅ $line"
    fi
done
echo ""

# Check inode usage
echo "2. INODE USAGE:"
df -i | head -1
df -i | grep -E "/$|/var|/tmp|/home" | while read line; do
    usage=$(echo $line | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        echo "⚠️  $line (HIGH INODE USAGE)"
    else
        echo "✅ $line"
    fi
done
echo ""

# Check memory usage
echo "3. MEMORY USAGE:"
free -h
echo ""

# Check file descriptor limits
echo "4. FILE DESCRIPTOR LIMITS:"
echo "Current fs.file-max: $(cat /proc/sys/fs/file-max)"
echo "Current fs.nr_open: $(cat /proc/sys/fs/nr_open)"
echo "Current open files: $(lsof 2>/dev/null | wc -l)"
echo "Max open files per process: $(ulimit -n)"
echo ""

# Check connection tracking
echo "5. CONNECTION TRACKING:"
if [ -f /proc/sys/net/netfilter/nf_conntrack_max ]; then
    conntrack_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
    conntrack_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "0")
    conntrack_usage=$((conntrack_count * 100 / conntrack_max))
    echo "Connection tracking max: $conntrack_max"
    echo "Connection tracking current: $conntrack_count"
    echo "Connection tracking usage: ${conntrack_usage}%"
    if [ "$conntrack_usage" -gt 80 ]; then
        echo "⚠️  Connection tracking usage is high!"
    else
        echo "✅ Connection tracking usage is normal"
    fi
else
    echo "Connection tracking not available"
fi
echo ""

# Check inotify watches
echo "6. INOTIFY WATCHES:"
echo "Max user watches: $(cat /proc/sys/fs/inotify/max_user_watches)"
current_watches=$(find /proc/*/fd -lname anon_inode:inotify -printf '%hinfo/%f\n' 2>/dev/null | xargs cat 2>/dev/null | grep -c '^inotify' || echo "0")
echo "Current watches: $current_watches"
echo ""

# Check Apache processes and memory
echo "7. APACHE PROCESSES:"
if pgrep httpd >/dev/null; then
    apache_procs=$(pgrep httpd | wc -l)
    apache_mem=$(ps aux | grep httpd | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
    echo "Apache processes: $apache_procs"
    echo "Apache total memory: ${apache_mem} MB"
    
    # Check Apache limits from ea4.conf if it exists
    if [ -f /etc/cpanel/ea4/ea4.conf ]; then
        echo "Apache configuration limits:"
        grep -E "maxclients|serverlimit|rlimit_mem" /etc/cpanel/ea4/ea4.conf 2>/dev/null || echo "Could not read Apache config"
    fi
else
    echo "Apache not running"
fi
echo ""

# Check recent 507 errors in logs
echo "8. RECENT 507 ERRORS:"
echo "Checking for 507 errors in logs..."
if [ -f /var/log/httpd/error_log ]; then
    recent_507=$(grep "507" /var/log/httpd/error_log | tail -5)
    if [ -n "$recent_507" ]; then
        echo "Recent 507 errors found:"
        echo "$recent_507"
    else
        echo "No recent 507 errors in Apache error log"
    fi
fi

if [ -f /var/log/nginx/error.log ]; then
    recent_507_nginx=$(grep "507" /var/log/nginx/error.log | tail -5)
    if [ -n "$recent_507_nginx" ]; then
        echo "Recent 507 errors in Nginx:"
        echo "$recent_507_nginx"
    else
        echo "No recent 507 errors in Nginx error log"
    fi
fi
echo ""

# Check for storage-related errors in system logs
echo "9. SYSTEM STORAGE ERRORS:"
storage_errors=$(grep -i "no space\|storage\|insufficient\|too many open files" /var/log/messages | tail -5)
if [ -n "$storage_errors" ]; then
    echo "Recent storage-related errors:"
    echo "$storage_errors"
else
    echo "No recent storage errors in system logs"
fi
echo ""

echo "=== RECOMMENDATIONS ==="
echo "If you're experiencing 507 errors, check:"
echo "1. Disk space usage (should be < 90%)"
echo "2. Inode usage (should be < 90%)"
echo "3. File descriptor limits vs current usage"
echo "4. Connection tracking table usage"
echo "5. Apache memory limits vs available memory"
echo "6. Recent error logs for specific causes" 