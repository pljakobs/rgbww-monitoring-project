#!/bin/bash

# RGBWW MQTT JSON Bridge Uninstaller for Native Deployment
# Removes the MQTT-to-InfluxDB bridge and all associated files

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
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       RGBWW MQTT JSON Bridge Uninstaller            ║"  
    echo "║                                                      ║"
    echo "║  Removes MQTT-to-InfluxDB bridge and all files      ║"
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
    echo -e "${YELLOW}⚠️  This will completely remove the RGBWW MQTT JSON Bridge${NC}"
    echo "   - Stop and disable the service"
    echo "   - Remove all files and directories"
    echo "   - Delete the service user"
    echo "   - Remove systemd service definition"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "🔄 Uninstall cancelled by user"
        exit 0
    fi
}

stop_and_disable_service() {
    log "${BLUE}� Stopping and disabling service...${NC}"
    
    if systemctl is-active rgbww-bridge >/dev/null 2>&1; then
        systemctl stop rgbww-bridge >> "$LOG_FILE" 2>&1
        log "   ✅ Service stopped"
    else
        log "   ℹ️  Service was not running"
    fi
    
    if systemctl is-enabled rgbww-bridge >/dev/null 2>&1; then
        systemctl disable rgbww-bridge >> "$LOG_FILE" 2>&1
        log "   ✅ Service disabled"
    else
        log "   ℹ️  Service was not enabled"
    fi
}

remove_systemd_service() {
    log "${BLUE}🗑️  Removing systemd service...${NC}"
    
    if [[ -f /etc/systemd/system/rgbww-bridge.service ]]; then
        rm /etc/systemd/system/rgbww-bridge.service
        log "   ✅ Service file removed"
    else
        log "   ℹ️  Service file not found"
    fi
    
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    log "   ✅ Systemd configuration reloaded"
}

remove_files() {
    log "${BLUE}� Removing application files...${NC}"
    
    # Remove application directory
    if [[ -d /opt/rgbww-bridge ]]; then
        rm -rf /opt/rgbww-bridge
        log "   ✅ Application directory removed: /opt/rgbww-bridge"
    else
        log "   ℹ️  Application directory not found"
    fi
    
    # Remove configuration directory
    if [[ -d /etc/rgbww-bridge ]]; then
        rm -rf /etc/rgbww-bridge
        log "   ✅ Configuration directory removed: /etc/rgbww-bridge"
    else
        log "   ℹ️  Configuration directory not found"
    fi
    
    # Remove log directory
    if [[ -d /var/log/rgbww-bridge ]]; then
        rm -rf /var/log/rgbww-bridge
        log "   ✅ Log directory removed: /var/log/rgbww-bridge"
    else
        log "   ℹ️  Log directory not found"
    fi
}

remove_user() {
    log "${BLUE}👤 Removing service user...${NC}"
    
    if id rgbww-bridge >/dev/null 2>&1; then
        userdel rgbww-bridge >> "$LOG_FILE" 2>&1
        log "   ✅ User 'rgbww-bridge' removed"
    else
        log "   ℹ️  User 'rgbww-bridge' not found"
    fi
}

print_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║               Uninstall Complete!                   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log "${GREEN}🎉 RGBWW MQTT JSON Bridge uninstalled successfully!${NC}"
    echo ""
    
    echo -e "${BLUE}📋 What was removed:${NC}"
    echo "   ✅ Systemd service: rgbww-bridge"
    echo "   ✅ Application files: /opt/rgbww-bridge"
    echo "   ✅ Configuration: /etc/rgbww-bridge"
    echo "   ✅ Log files: /var/log/rgbww-bridge"
    echo "   ✅ Service user: rgbww-bridge"
    echo ""
    
    echo -e "${YELLOW}� Note:${NC}"
    echo "   - InfluxDB data was not removed"
    echo "   - Python packages remain installed"
    echo "   - System packages (python3, pip) remain installed"
    echo ""
    
    log "${GREEN}✅ Uninstall completed at $UNINSTALL_DATE${NC}"
    log "📄 Uninstall log: $LOG_FILE"
}

# Main uninstall flow
main() {
    print_header
    
    log "🗑️  Starting RGBWW MQTT JSON Bridge uninstall..."
    log "📄 Uninstall log: $LOG_FILE"
    echo ""
    
    check_root
    confirm_uninstall
    stop_and_disable_service
    remove_systemd_service
    remove_files
    remove_user
    
    echo ""
    print_completion
}

# Handle script interruption
trap 'log "${RED}❌ Uninstall interrupted${NC}"; exit 1' INT TERM

# Run main uninstall
main "$@"