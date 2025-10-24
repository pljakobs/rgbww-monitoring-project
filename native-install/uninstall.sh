#!/bin/bash

# RGBWW IoT Device Monitoring System Uninstaller
# Removes all components of the RGBWW monitoring system

set -e

LOG_FILE="/tmp/rgbww-uninstall.log"
UNINSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

print_header() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       RGBWW IoT Monitoring System Uninstaller       ║"  
    echo "║                                                      ║"
    echo "║           ⚠️  This will remove all components        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "${RED}❌ This script must be run as root${NC}"
        exit 1
    fi
}

confirm_uninstall() {
    echo -e "${YELLOW}⚠️  WARNING: This will remove:${NC}"
    echo "   • IoT Discovery timer and services"
    echo "   • JSON Exporter service"
    echo "   • Configuration files in /etc/prometheus/"
    echo "   • Management scripts"
    echo "   • Device lists and metadata"
    echo ""
    echo -e "${YELLOW}📊 Prometheus itself will NOT be removed${NC}"
    echo ""
    
    read -p "Are you sure you want to uninstall? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Uninstall cancelled by user"
        exit 0
    fi
    echo ""
}

stop_services() {
    log "${BLUE}🔧 Stopping services...${NC}"
    
    # Stop and disable timer
    if systemctl is-active iot-discovery.timer >/dev/null 2>&1; then
        systemctl stop iot-discovery.timer >> "$LOG_FILE" 2>&1
        log "   ✅ Stopped iot-discovery.timer"
    fi
    
    if systemctl is-enabled iot-discovery.timer >/dev/null 2>&1; then
        systemctl disable iot-discovery.timer >> "$LOG_FILE" 2>&1
        log "   ✅ Disabled iot-discovery.timer"
    fi
    
    # Stop JSON Exporter
    if systemctl is-active json_exporter >/dev/null 2>&1; then
        systemctl stop json_exporter >> "$LOG_FILE" 2>&1
        log "   ✅ Stopped json_exporter"
    fi
    
    if systemctl is-enabled json_exporter >/dev/null 2>&1; then
        systemctl disable json_exporter >> "$LOG_FILE" 2>&1
        log "   ✅ Disabled json_exporter"
    fi
}

remove_systemd_files() {
    log "${BLUE}🗑️  Removing systemd files...${NC}"
    
    local files=(
        "/etc/systemd/system/iot-discovery.service"
        "/etc/systemd/system/iot-discovery.timer"
        "/etc/systemd/system/json_exporter.service"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            rm "$file"
            log "   ✅ Removed $file"
        fi
    done
    
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    log "   ✅ Reloaded systemd"
}

remove_binaries() {
    log "${BLUE}🗑️  Removing binaries...${NC}"
    
    if [[ -f /usr/local/bin/json_exporter ]]; then
        rm /usr/local/bin/json_exporter
        log "   ✅ Removed /usr/local/bin/json_exporter"
    fi
}

remove_config_files() {
    log "${BLUE}🗑️  Removing configuration files...${NC}"
    
    local files=(
        "/etc/prometheus/json_exporter.yml"
        "/etc/prometheus/prometheus.yml.template"
        "/etc/prometheus/manage-iot-devices.sh"
        "/etc/prometheus/iot-status.sh"
        "/etc/prometheus/iot-devices.txt"
        "/etc/prometheus/iot-device-metadata.json"
        "/etc/prometheus/README.md"
        "/etc/logrotate.d/iot-discovery"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            rm "$file"
            log "   ✅ Removed $file"
        fi
    done
}

cleanup_logs() {
    log "${BLUE}🧹 Cleaning up logs...${NC}"
    
    # Clean systemd logs
    journalctl --vacuum-time=1s --unit=iot-discovery.service >/dev/null 2>&1 || true
    journalctl --vacuum-time=1s --unit=json_exporter.service >/dev/null 2>&1 || true
    
    log "   ✅ Cleaned up systemd logs"
}

restore_prometheus_config() {
    log "${BLUE}⚙️  Checking Prometheus configuration...${NC}"
    
    if [[ -f /etc/prometheus/prometheus.yml ]]; then
        # Check if our IoT configuration exists
        if grep -q "iot-devices" /etc/prometheus/prometheus.yml 2>/dev/null; then
            log "${YELLOW}⚠️  Found IoT device configuration in prometheus.yml${NC}"
            log "   Manual cleanup of /etc/prometheus/prometheus.yml may be needed"
            log "   Consider removing the 'iot-devices' job configuration"
        else
            log "   ✅ No IoT configuration found in prometheus.yml"
        fi
    fi
}

print_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                Uninstall Complete!                  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log "${GREEN}🎉 RGBWW IoT Monitoring System uninstalled successfully!${NC}"
    echo ""
    
    echo -e "${BLUE}📋 What was removed:${NC}"
    echo "   ✅ IoT Discovery timer and service"
    echo "   ✅ JSON Exporter service and binary"
    echo "   ✅ Configuration files"
    echo "   ✅ Management scripts"
    echo "   ✅ Device lists and metadata"
    echo "   ✅ Systemd service files"
    echo "   ✅ Log files"
    echo ""
    
    echo -e "${YELLOW}📋 Manual cleanup needed:${NC}"
    echo "   • Check /etc/prometheus/prometheus.yml for IoT job config"
    echo "   • Prometheus service is still running"
    echo "   • Dependencies (jq, curl) were not removed"
    echo ""
    
    log "${GREEN}✅ Uninstall completed at $UNINSTALL_DATE${NC}"
    log "📄 Uninstall log: $LOG_FILE"
}

# Main uninstall flow
main() {
    print_header
    
    log "🗑️  Starting RGBWW IoT Monitoring System uninstall..."
    log "📄 Uninstall log: $LOG_FILE"
    echo ""
    
    check_root
    confirm_uninstall
    stop_services
    remove_systemd_files
    remove_binaries
    remove_config_files
    cleanup_logs
    restore_prometheus_config
    
    echo ""
    print_completion
}

# Handle script interruption
trap 'log "${RED}❌ Uninstall interrupted${NC}"; exit 1' INT TERM

# Run main uninstall
main "$@"