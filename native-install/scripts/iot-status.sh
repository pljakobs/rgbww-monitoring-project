#!/bin/bash

# IoT Discovery System Status Script
# Shows the status of the automated IoT device discovery system

echo "🔍 IoT Device Discovery System Status"
echo "======================================"
echo ""

# Check timer status
echo "⏰ Timer Status:"
systemctl is-active iot-discovery.timer >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ Timer is active"
    echo "   📅 Next run: $(systemctl list-timers iot-discovery.timer --no-legend | awk '{print $1, $2}')"
else
    echo "   ❌ Timer is not active"
fi
echo ""

# Check service status
echo "🔧 Service Status:"
echo "   📊 Prometheus: $(systemctl is-active prometheus)"
echo "   📈 JSON Exporter: $(systemctl is-active json_exporter)"
echo ""

# Check device count
echo "📱 Current Devices:"
if [ -f "/etc/prometheus/iot-devices.txt" ]; then
    device_count=$(wc -l < "/etc/prometheus/iot-devices.txt")
    echo "   📋 Total devices: $device_count"
    echo "   📋 Last updated: $(stat -c %y /etc/prometheus/iot-devices.txt | cut -d'.' -f1)"
else
    echo "   ❌ No devices file found"
fi
echo ""

# Check recent discovery runs
echo "📊 Recent Discovery Runs:"
journalctl -u iot-discovery.service --since "24 hours ago" --no-pager -q | grep -E "(Starting automated|completed|Device count)" | tail -5 | while read line; do
    echo "   $line"
done
echo ""

# Check for errors
echo "⚠️  Recent Errors:"
error_count=$(journalctl -u iot-discovery.service --since "24 hours ago" --no-pager -q -p err | wc -l)
if [ $error_count -gt 0 ]; then
    echo "   ❌ Found $error_count errors in last 24 hours"
    journalctl -u iot-discovery.service --since "24 hours ago" --no-pager -q -p err | tail -3
else
    echo "   ✅ No errors in last 24 hours"
fi
echo ""

echo "🔗 Useful Commands:"
echo "   systemctl status iot-discovery.timer      # Check timer status"
echo "   journalctl -u iot-discovery.service -f    # Follow discovery logs"
echo "   /etc/prometheus/manage-iot-devices.sh list # List current devices"
echo "   systemctl stop iot-discovery.timer        # Disable auto-discovery"