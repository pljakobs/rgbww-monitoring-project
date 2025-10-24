#!/bin/bash

# RGBWW Prometheus Container Entrypoint
# Performs initial device discovery and starts Prometheus

set -e

echo "🔍 Starting RGBWW IoT Device Discovery..."

# Check for initial controller IP
if [ -n "$INITIAL_CONTROLLER_IP" ]; then
    echo "📍 Using initial controller: $INITIAL_CONTROLLER_IP"
    # Add initial controller to seed the discovery
    echo "$INITIAL_CONTROLLER_IP" > /etc/prometheus/iot-devices.txt
    # Run discovery with the seed device
    /etc/prometheus/manage-iot-devices.sh discover
elif [ -n "$NETWORK_RANGE" ]; then
    echo "🌐 Scanning network range: $NETWORK_RANGE"
    # Scan network range for devices
    /etc/prometheus/manage-iot-devices.sh scan "$NETWORK_RANGE"
else
    echo "⚠️  No initial controller specified. Set INITIAL_CONTROLLER_IP environment variable."
    echo "   Example: INITIAL_CONTROLLER_IP=192.168.1.100"
    echo "   Or set NETWORK_RANGE for scanning: NETWORK_RANGE=192.168.1.0/24"
    echo "🔍 Attempting network discovery anyway..."
    /etc/prometheus/manage-iot-devices.sh discover
fi

# Set up background discovery (every 30 minutes)
(
    while true; do
        sleep 1800  # 30 minutes
        echo "🔄 Running scheduled device discovery..."
        /etc/prometheus/manage-iot-devices.sh auto
    done
) &

echo "✅ Device discovery started"
echo "🚀 Starting Prometheus..."

# Start Prometheus with passed arguments
exec /usr/local/bin/prometheus "$@"