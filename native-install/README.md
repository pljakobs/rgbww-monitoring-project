# RGBWW MQTT JSON Bridge - Native Installation

## Overview
Native installation of the RGBWW MQTT JSON Bridge that:
- Collects telemetry and log data from RGBWW IoT devices via MQTT
- Stores data in InfluxDB with proper time-series organization
- Provides HTTP endpoint for metrics and status monitoring
- Runs as a systemd service with automatic restart capabilities

## System Components

### 1. Core Service
- **Location**: `/opt/rgbww-bridge/mqtt-json-bridge.py`
- **Purpose**: MQTT-to-InfluxDB data bridge with device monitoring
- **Features**:
  - MQTT subscription to device stats and logs
  - Automatic JSON flattening for InfluxDB storage
  - Device ID-based tagging for stable identification
  - HTTP metrics endpoint for monitoring

### 2. Configuration
- **Config file**: `/etc/rgbww-bridge/config.ini`
- **Log directory**: `/var/log/rgbww-bridge/`
- **Python environment**: `/opt/rgbww-bridge/venv/`

### 3. Systemd Service
- **Service**: `rgbww-bridge.service`
- **User**: `rgbww-bridge` (dedicated system user)
- **Auto-restart**: Enabled with 10-second delay
- **Logging**: Journal integration

## Installation

### Prerequisites
- Ubuntu/Debian-based system with systemd
- Root access for installation
- Access to MQTT broker with RGBWW device data
- InfluxDB instance (local or remote)

### Quick Install
```bash
sudo ./install.sh
```

### Manual Configuration
After installation, edit the configuration:
```bash
sudo nano /etc/rgbww-bridge/config.ini
```

Update the following sections:
```ini
[mqtt]
broker = your-mqtt-broker.com
username = your-username
password = your-password

[influxdb]
url = http://localhost:8086
org = your-org
bucket = rgbww
token = your-influxdb-token
```

### Service Management
```bash
# Enable and start the service
sudo systemctl enable rgbww-bridge
sudo systemctl start rgbww-bridge

# Check service status
sudo systemctl status rgbww-bridge

# View logs
sudo journalctl -u rgbww-bridge -f

# Restart service
sudo systemctl restart rgbww-bridge
```

## Data Collection

### MQTT Topics
The bridge subscribes to:
- `rgbww/+/monitor` - Device telemetry data
- `rgbww/+/log` - Device log messages

### InfluxDB Measurements
- **rgbww_debug_data** - Device telemetry with device ID tags
- **rgbww_log** - Device log messages with device ID tags

### Metrics Endpoint
Access live metrics at: `http://localhost:8001/metrics.json`

## Key Features

### Device ID Tagging
- All metrics tagged with stable device IDs from MQTT topics
- Device IDs remain constant across IP changes and reboots
- Enables consistent time-series analysis

### JSON Flattening
- Nested JSON data automatically flattened for InfluxDB storage
- Intelligent type conversion (integers, floats, strings)
- Configurable field type enforcement

### Robust Error Handling
- Connection retry logic for MQTT and InfluxDB
- Graceful handling of malformed messages
- Service auto-restart on failures

### Buffer Management
- Configurable message buffering
- Periodic batch writes to InfluxDB
- Memory-efficient circular buffer

## Configuration Options

### MQTT Settings
```ini
[mqtt]
broker = mqtt.example.com    # MQTT broker hostname
port = 1883                  # MQTT broker port
username = mqtt_user         # MQTT username
password = mqtt_pass         # MQTT password
stats_topic = rgbww/+/monitor    # Topic pattern for device stats
log_topic = rgbww/+/log          # Topic pattern for device logs
```

### Application Settings
```ini
[application]
buffer_size = 10             # Message buffer size multiplier
http_port = 8001            # HTTP metrics endpoint port
write_interval = 5          # InfluxDB write interval (seconds)
```

### InfluxDB Settings
```ini
[influxdb]
url = http://localhost:8086  # InfluxDB URL
org = your-org              # InfluxDB organization
bucket = rgbww              # InfluxDB bucket
token = your-token          # InfluxDB authentication token
```

## Monitoring and Troubleshooting

### Service Status
```bash
# Check if service is running
sudo systemctl is-active rgbww-bridge

# View detailed status
sudo systemctl status rgbww-bridge

# Check for service failures
sudo systemctl is-failed rgbww-bridge
```

### Log Analysis
```bash
# Follow real-time logs
sudo journalctl -u rgbww-bridge -f

# View recent logs
sudo journalctl -u rgbww-bridge --since "1 hour ago"

# Search for errors
sudo journalctl -u rgbww-bridge | grep -i error
```

### HTTP Metrics
```bash
# Check service health
curl http://localhost:8001/metrics.json

# Test with formatting
curl -s http://localhost:8001/metrics.json | python3 -m json.tool
```

### Common Issues

**Service won't start:**
```bash
# Check configuration syntax
sudo -u rgbww-bridge /opt/rgbww-bridge/venv/bin/python /opt/rgbww-bridge/mqtt-json-bridge.py
```

**No data in InfluxDB:**
- Verify InfluxDB token and permissions
- Check MQTT broker connectivity
- Ensure devices are publishing to correct topics

**High memory usage:**
- Reduce buffer_size in configuration
- Check for message processing bottlenecks
- Monitor InfluxDB write performance

## Security Considerations

### Service User
- Runs as dedicated `rgbww-bridge` system user
- No shell access or home directory
- Minimal system privileges

### File Permissions
- Configuration files owned by `rgbww-bridge` user
- Service binary in protected system directory
- Log files with appropriate permissions

### Network Security
- MQTT credentials stored in configuration file
- InfluxDB token authentication
- HTTP endpoint on localhost only (configurable)

## Uninstallation

To remove the service:
```bash
sudo ./uninstall.sh
```

Or manually:
```bash
# Stop and disable service
sudo systemctl stop rgbww-bridge
sudo systemctl disable rgbww-bridge

# Remove files
sudo rm -rf /opt/rgbww-bridge
sudo rm -rf /etc/rgbww-bridge
sudo rm -rf /var/log/rgbww-bridge
sudo rm /etc/systemd/system/rgbww-bridge.service

# Remove user
sudo userdel rgbww-bridge

# Reload systemd
sudo systemctl daemon-reload
```

Current Status: ✅ **READY** - Service installed and ready for configuration