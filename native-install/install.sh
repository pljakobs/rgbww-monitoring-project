#!/bin/bash

# RGBWW MQTT JSON Bridge Installer for Native Deployment
# Installs the MQTT-to-InfluxDB bridge for IoT device monitoring

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
    echo "║       RGBWW MQTT JSON Bridge Native Installer       ║"  
    echo "║                                                      ║"
    echo "║  MQTT-to-InfluxDB bridge for IoT device monitoring  ║"
    echo "║  with centralized logging and telemetry collection  ║"
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
    
    # Check Python 3
    if ! command -v python3 >/dev/null 2>&1; then
        log "${RED}❌ Python 3 is required${NC}"
        exit 1
    fi
    log "   ✅ Python 3 detected: $(python3 --version)"
}

install_dependencies() {
    log "${BLUE}📦 Installing dependencies...${NC}"
    
    # Update package list
    apt-get update >> "$LOG_FILE" 2>&1
    
    # Install required packages
    local packages=(
        "python3"
        "python3-pip"
        "python3-venv"
        "curl"
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

create_service_user() {
    log "${BLUE}👤 Setting up rgbww-bridge user...${NC}"
    
    if ! id rgbww-bridge >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /bin/false rgbww-bridge >> "$LOG_FILE" 2>&1
        log "   ✅ Created rgbww-bridge user"
    else
        log "   ✅ rgbww-bridge user already exists"
    fi
}

install_mqtt_bridge() {
    log "${BLUE}📡 Installing MQTT JSON Bridge...${NC}"
    
    # Create installation directory
    mkdir -p /opt/rgbww-bridge
    mkdir -p /etc/rgbww-bridge
    mkdir -p /var/log/rgbww-bridge
    
    # Copy the updated importer script
    cp "$SCRIPT_DIR/../rgbww-importer/mqtt-json-bridge.py" /opt/rgbww-bridge/
    cp "$SCRIPT_DIR/../rgbww-importer/config.ini" /etc/rgbww-bridge/config.ini.example
    
    # Set permissions
    chown -R rgbww-bridge:rgbww-bridge /opt/rgbww-bridge
    chown -R rgbww-bridge:rgbww-bridge /etc/rgbww-bridge
    chown -R rgbww-bridge:rgbww-bridge /var/log/rgbww-bridge
    chmod +x /opt/rgbww-bridge/mqtt-json-bridge.py
    
    log "   ✅ MQTT JSON Bridge installed"
}

setup_python_environment() {
    log "${BLUE}� Setting up Python virtual environment...${NC}"
    
    # Create virtual environment
    python3 -m venv /opt/rgbww-bridge/venv >> "$LOG_FILE" 2>&1
    
    # Install Python dependencies
    /opt/rgbww-bridge/venv/bin/pip install --upgrade pip >> "$LOG_FILE" 2>&1
    /opt/rgbww-bridge/venv/bin/pip install paho-mqtt influxdb-client flask configparser >> "$LOG_FILE" 2>&1
    
    # Set permissions
    chown -R rgbww-bridge:rgbww-bridge /opt/rgbww-bridge/venv
    
    log "   ✅ Python environment configured"
}

install_systemd_service() {
    log "${BLUE}🔧 Installing systemd service...${NC}"
    
    # Create systemd service file
    cat > /etc/systemd/system/rgbww-bridge.service << 'EOF'
[Unit]
Description=RGBWW MQTT JSON Bridge
After=network.target

[Service]
Type=simple
User=rgbww-bridge
Group=rgbww-bridge
WorkingDirectory=/opt/rgbww-bridge
ExecStart=/opt/rgbww-bridge/venv/bin/python /opt/rgbww-bridge/mqtt-json-bridge.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    
    log "   ✅ Systemd service installed"
}

setup_configuration() {
    log "${BLUE}⚙️  Setting up configuration...${NC}"
    
    if [[ ! -f /etc/rgbww-bridge/config.ini ]]; then
        log "   📝 Creating default configuration..."
        cat > /etc/rgbww-bridge/config.ini << 'EOF'
# MQTT JSON Bridge Configuration for Native Deployment
# Customize these settings for your environment

[mqtt]
broker = your-mqtt-broker.com
port = 1883
username = your-username
password = your-password
stats_topic = rgbww/+/monitor
log_topic = rgbww/+/log

[application]
buffer_size = 10
http_port = 8001
write_interval = 5
stats_interval = 300

[influxdb]
# Update these settings for your local InfluxDB installation
url = http://localhost:8086
org = your-org
bucket = rgbww
token = your-influxdb-token-here
EOF
        chown rgbww-bridge:rgbww-bridge /etc/rgbww-bridge/config.ini
        log "   ✅ Default configuration created"
    else
        log "   ✅ Configuration file already exists"
    fi
}

print_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                 Installation Complete!              ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    log "${GREEN}🎉 RGBWW MQTT JSON Bridge installed successfully!${NC}"
    echo ""
    
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Configure the bridge:"
    echo "   sudo nano /etc/rgbww-bridge/config.ini"
    echo ""
    echo "2. Update MQTT and InfluxDB settings in the config file"
    echo ""
    echo "3. Start the service:"
    echo "   sudo systemctl enable rgbww-bridge"
    echo "   sudo systemctl start rgbww-bridge"
    echo ""
    echo "4. Check service status:"
    echo "   sudo systemctl status rgbww-bridge"
    echo ""
    echo "5. View logs:"
    echo "   sudo journalctl -u rgbww-bridge -f"
    echo ""
    
    echo -e "${BLUE}� Service Endpoints:${NC}"
    echo "   HTTP metrics: http://localhost:8001/metrics.json"
    echo ""
    
    echo -e "${BLUE}� Files Created:${NC}"
    echo "   Service: /opt/rgbww-bridge/mqtt-json-bridge.py"
    echo "   Config:  /etc/rgbww-bridge/config.ini"
    echo "   Systemd: /etc/systemd/system/rgbww-bridge.service"
    echo "   Logs:    /var/log/rgbww-bridge/"
    echo ""
    
    log "${GREEN}✅ Installation completed at $INSTALL_DATE${NC}"
    log "📄 Installation log: $LOG_FILE"
}

# Main installation flow
main() {
    print_header
    
    log "🚀 Starting RGBWW MQTT JSON Bridge installation..."
    log "📄 Installation log: $LOG_FILE"
    echo ""
    
    check_root
    check_system
    install_dependencies
    create_service_user
    install_mqtt_bridge
    setup_python_environment
    install_systemd_service
    setup_configuration
    
    echo ""
    print_completion
}

# Handle script interruption
trap 'log "${RED}❌ Installation interrupted${NC}"; exit 1' INT TERM

# Run main installation
main "$@"