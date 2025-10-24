# IoT Device Discovery System

## Overview
Automated IoT device discovery and monitoring system that:
- Auto-discovers devices every 30 minutes using network topology crawling
- Maintains Prometheus configuration with device IDs as primary keys
- Automatically restarts Prometheus when device list changes
- Provides comprehensive device metadata and monitoring

## System Components

### 1. Core Script
- **Location**: `/etc/prometheus/manage-iot-devices.sh`
- **Purpose**: Device management, discovery, and Prometheus configuration
- **Commands**:
  - `discover [ip]` - Manual network discovery
  - `auto-discover` - Automated discovery for timer
  - `list` - Show all devices with names and IDs
  - `add <ip>` - Manually add a device
  - `remove <ip>` - Remove a device
  - `refresh` - Update device metadata
  - `test <ip>` - Test device connectivity

### 2. Systemd Timer
- **Service**: `iot-discovery.service`
- **Timer**: `iot-discovery.timer` 
- **Schedule**: Every 30 minutes (randomized ±5min)
- **Boot delay**: 2 minutes after system start
- **Persistence**: Catches up missed runs

### 3. Configuration Files
- **Device list**: `/etc/prometheus/iot-devices.txt`
- **Device metadata**: `/etc/prometheus/iot-device-metadata.json`
- **Prometheus config**: `/etc/prometheus/prometheus.yml`
- **JSON exporter config**: `/etc/prometheus/json_exporter.yml`
- **Prometheus template**: `/etc/prometheus/prometheus.yml.template`

### 4. Monitoring
- **Status script**: `/etc/prometheus/iot-status.sh`
- **Log rotation**: `/etc/logrotate.d/iot-discovery`
- **Service logs**: `journalctl -u iot-discovery.service`

## Key Features

### Device ID as Primary Key
- All metrics use stable device IDs (e.g., "2827530") as primary identifier
- Device IDs remain constant across IP changes, renames, reboots
- Human-readable device names available as labels

### Network Topology Discovery
- Multi-round crawling queries all discovered devices
- Finds devices that might not be visible from initial discovery point
- Handles partial network knowledge scenarios

### Automatic Updates
- Detects new devices and adds them automatically
- Updates Prometheus configuration
- Restarts Prometheus only when changes detected
- Maintains device metadata (names, IDs, discovery timestamps)

### Comprehensive Metrics
Available metrics with device ID as primary key:
- `device_info` - Device metadata and labels
- `device_uptime_seconds` - Device uptime
- `device_heap_free_bytes` - Free memory
- `device_event_clients_total` - Connected clients
- `device_connection_status` - WiFi connection status
- `device_dhcp_enabled` - DHCP configuration
- `device_rgbww_queue_size` - RGBWW queue status

## Usage Examples

```bash
# Check system status
/etc/prometheus/iot-status.sh

# Manual discovery
/etc/prometheus/manage-iot-devices.sh discover 192.168.29.101

# List all devices
/etc/prometheus/manage-iot-devices.sh list

# Test device connectivity
/etc/prometheus/manage-iot-devices.sh test 192.168.29.101

# View discovery logs
journalctl -u iot-discovery.service -f

# Check timer status
systemctl status iot-discovery.timer

# Disable auto-discovery
systemctl stop iot-discovery.timer

# Re-enable auto-discovery
systemctl start iot-discovery.timer
```

## Security Features
- Systemd service runs with minimal privileges
- Network access restricted to necessary capabilities
- Private temporary directories
- Protected system directories
- No new privileges allowed

## Prometheus Integration
- Device ID based instance labels for metric continuity
- Rich metadata labels for filtering and grouping
- Automatic relabeling from IP addresses to device IDs
- Source IP preserved for debugging

Current Status: ✅ **ACTIVE** - Monitoring 11 IoT devices with 30-minute auto-discovery