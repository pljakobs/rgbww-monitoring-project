#!/bin/bash

# RGBWW IoT Device Monitoring System Installer
# Automated installation of Prometheus-based IoT device discovery and monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/rgbww-install.log"
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')

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
    echo "║         RGBWW IoT Monitoring System Installer       ║"  
    echo "║                                                      ║"
    echo "║  Automated Prometheus-based IoT device discovery    ║"
    echo "║  and monitoring with device ID primary keys         ║"
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

check_system() {
    log "${BLUE}🔍 Checking system requirements...${NC}"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log "${RED}❌ Cannot determine OS version${NC}"
        exit 1
    fi
    
    source /etc/os-release
    log "   ✅ OS: $PRETTY_NAME"
    
    # Check systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        log "${RED}❌ systemd is required${NC}"
        exit 1
    fi
    log "   ✅ systemd detected"
    
    # Check if running in container
    if [[ -f /.dockerenv ]]; then
        log "${YELLOW}⚠️  Running in Docker container - some features may not work${NC}"
    fi
}

install_dependencies() {
    log "${BLUE}📦 Installing dependencies...${NC}"
    
    # Update package list
    apt-get update >> "$LOG_FILE" 2>&1
    
    # Install required packages
    local packages=(
        "curl"
        "jq"
        "wget"
        "prometheus"
        "logrotate"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "   📦 Installing $package..."
            apt-get install -y "$package" >> "$LOG_FILE" 2>&1
        else
            log "   ✅ $package already installed"
        fi
    done
}

install_json_exporter() {
    log "${BLUE}📊 Installing JSON Exporter...${NC}"
    
    local version="0.6.0"
    local arch="linux-amd64"
    local url="https://github.com/prometheus-community/json_exporter/releases/download/v${version}/json_exporter-${version}.${arch}.tar.gz"
    
    # Check if already installed
    if [[ -f /usr/local/bin/json_exporter ]]; then
        local current_version=$(/usr/local/bin/json_exporter --version 2>&1 | head -n1 || echo "unknown")
        log "   ✅ JSON Exporter already installed: $current_version"
        return
    fi
    
    log "   📥 Downloading JSON Exporter v$version..."
    cd /tmp
    wget -q "$url" >> "$LOG_FILE" 2>&1
    
    log "   📦 Extracting..."
    tar -xzf "json_exporter-${version}.${arch}.tar.gz" >> "$LOG_FILE" 2>&1
    
    log "   📋 Installing..."
    cp "json_exporter-${version}.${arch}/json_exporter" /usr/local/bin/
    chmod +x /usr/local/bin/json_exporter
    
    # Clean up
    rm -rf "json_exporter-${version}.${arch}"*
    
    log "   ✅ JSON Exporter installed successfully"
}

create_prometheus_user() {
    log "${BLUE}👤 Setting up prometheus user...${NC}"
    
    if ! id prometheus >/dev/null 2>&1; then
        useradd --no-create-home --shell /bin/false prometheus >> "$LOG_FILE" 2>&1
        log "   ✅ Created prometheus user"
    else
        log "   ✅ prometheus user already exists"
    fi
}

install_configs() {
    log "${BLUE}⚙️  Installing configuration files...${NC}"
    
    # Create directories
    mkdir -p /etc/prometheus
    
    # Install config files
    cp "$SCRIPT_DIR/config/json_exporter.yml" /etc/prometheus/
    cp "$SCRIPT_DIR/config/prometheus.yml.template" /etc/prometheus/
    cp "$SCRIPT_DIR/config/logrotate-iot-discovery" /etc/logrotate.d/iot-discovery
    
    # Set permissions
    chown prometheus:prometheus /etc/prometheus/json_exporter.yml
    chmod 644 /etc/prometheus/prometheus.yml.template
    
    log "   ✅ Configuration files installed"
}

install_scripts() {
    log "${BLUE}📝 Installing management scripts...${NC}"
    
    # Install scripts
    cp "$SCRIPT_DIR/scripts/manage-iot-devices.sh" /etc/prometheus/
    cp "$SCRIPT_DIR/scripts/iot-status.sh" /etc/prometheus/
    
    # Make executable
    chmod +x /etc/prometheus/manage-iot-devices.sh
    chmod +x /etc/prometheus/iot-status.sh
    
    log "   ✅ Management scripts installed"
}

install_systemd_services() {
    log "${BLUE}🔧 Installing systemd services...${NC}"
    
    # Install service files
    cp "$SCRIPT_DIR/systemd/json_exporter.service" /etc/systemd/system/
    cp "$SCRIPT_DIR/systemd/iot-discovery.service" /etc/systemd/system/
    cp "$SCRIPT_DIR/systemd/iot-discovery.timer" /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    
    log "   ✅ Systemd services installed"
}

enable_services() {
    log "${BLUE}🚀 Enabling and starting services...${NC}"
    
    # Enable and start Prometheus (if not already running)
    if ! systemctl is-active prometheus >/dev/null 2>&1; then
        systemctl enable prometheus >> "$LOG_FILE" 2>&1
        systemctl start prometheus >> "$LOG_FILE" 2>&1
        log "   ✅ Prometheus enabled and started"
    else
        log "   ✅ Prometheus already running"
    fi
    
    # Enable and start JSON Exporter
    systemctl enable json_exporter >> "$LOG_FILE" 2>&1
    systemctl start json_exporter >> "$LOG_FILE" 2>&1
    log "   ✅ JSON Exporter enabled and started"
    
    # Enable discovery timer (but don't start until devices are configured)
    systemctl enable iot-discovery.timer >> "$LOG_FILE" 2>&1
    log "   ✅ IoT Discovery timer enabled (not started yet)"
}

setup_initial_config() {
    log "${BLUE}📋 Setting up initial configuration...${NC}"
    
    # Initialize empty device files
    touch /etc/prometheus/iot-devices.txt
    echo "{}" > /etc/prometheus/iot-device-metadata.json
    
    # Set permissions
    chown prometheus:prometheus /etc/prometheus/iot-device*.txt /etc/prometheus/iot-device*.json 2>/dev/null || true
    
    log "   ✅ Initial configuration files created"
}

print_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                 Installation Complete!              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log "${GREEN}🎉 RGBWW IoT Monitoring System installed successfully!${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Discover your IoT devices:"
    echo "   /etc/prometheus/manage-iot-devices.sh discover <device_ip>"
    echo ""
    echo "2. Start automated discovery:"
    echo "   systemctl start iot-discovery.timer"
    echo ""
    echo "3. Check system status:"
    echo "   /etc/prometheus/iot-status.sh"
    echo ""
    echo "4. Access Prometheus:"
    echo "   http://localhost:9090"
    echo ""
    
    echo -e "${BLUE}📚 Documentation:${NC}"
    echo "   /root/rgbww/README.md"
    echo ""
    
    echo -e "${BLUE}📊 Useful Commands:${NC}"
    echo "   /etc/prometheus/manage-iot-devices.sh list    # List devices"
    echo "   journalctl -u iot-discovery.service -f       # Follow logs"
    echo "   systemctl status iot-discovery.timer         # Timer status"
    echo ""
    
    log "${GREEN}✅ Installation completed at $INSTALL_DATE${NC}"
    log "📄 Installation log: $LOG_FILE"
}

# Main installation flow
main() {
    print_header
    
    log "🚀 Starting RGBWW IoT Monitoring System installation..."
    log "📄 Installation log: $LOG_FILE"
    echo ""
    
    check_root
    check_system
    install_dependencies
    install_json_exporter
    create_prometheus_user
    install_configs
    install_scripts
    install_systemd_services
    enable_services
    setup_initial_config
    
    echo ""
    print_completion
}

# Handle script interruption
trap 'log "${RED}❌ Installation interrupted${NC}"; exit 1' INT TERM

# Run main installation
main "$@"