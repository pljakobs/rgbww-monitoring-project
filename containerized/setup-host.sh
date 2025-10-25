#!/bin/bash
# RGBWW Monitoring Stack Host Setup Script
# Creates required host directories and sets permissions for SELinux compatibility

set -e

PROM_TEXTFILE_DIR="/var/lib/containers/rgbww-monitoring/textfile_collector"
PROM_BASE_DIR="/var/lib/containers/rgbww-monitoring"

# Create base directory if missing
if [ ! -d "$PROM_BASE_DIR" ]; then
    sudo mkdir -p "$PROM_BASE_DIR"
fi

# Create textfile_collector directory if missing
if [ ! -d "$PROM_TEXTFILE_DIR" ]; then
    sudo mkdir -p "$PROM_TEXTFILE_DIR"
fi

# Set ownership to Prometheus UID (100)
sudo chown 100:100 "$PROM_TEXTFILE_DIR"

# Set SELinux context for container access
if command -v chcon &>/dev/null; then
    sudo chcon -Rt container_file_t "$PROM_TEXTFILE_DIR"
fi

echo "✅ Host directories for Prometheus textfile collector are ready."
echo "   Path: $PROM_TEXTFILE_DIR"
echo "   Ownership: 100:100"
echo "   SELinux context: container_file_t"
