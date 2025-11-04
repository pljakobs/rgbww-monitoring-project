# 🎯 RGBWW IoT Device Monitoring System

A comprehensive monitoring solution for RGBWW IoT devices with MQTT data collection, InfluxDB storage, and Grafana dashboards. Supports both containerized and native deployments using a unified MQTT JSON bridge.

## ✨ Features

- **📡 MQTT Data Collection**: Collects telemetry and log data from RGBWW IoT devices
- **💾 InfluxDB Storage**: Time-series database for efficient metric storage  
- **📊 Grafana Dashboards**: Pre-configured dashboards for device monitoring
- **🔧 Unified Importer**: Single MQTT-to-InfluxDB bridge for both deployment types
- **📋 Device Logs**: Centralized log collection and analysis
- **⚡ Real-time Metrics**: Live device telemetry and status monitoring
- **🔑 Device ID Tagging**: Stable device identification across IP changes

## 🚀 Quick Start

### Option 1: Containerized Deployment (Recommended)

```bash
cd containerized/
# Copy and edit configuration
cp rgbww-importer-config.ini.example rgbww-importer-config.ini
# Edit with your MQTT and InfluxDB settings
nano rgbww-importer-config.ini
# Start all services
docker-compose up -d
```

### Option 2: Native Installation

```bash
cd native-install/
sudo ./install.sh
# Edit configuration
sudo nano /etc/rgbww-bridge/config.ini
# Start service
sudo systemctl enable rgbww-bridge
sudo systemctl start rgbww-bridge
```

## 📊 What You Get

### MQTT Data Collection

| Topic Pattern | Purpose | Storage |
|---------------|---------|---------|
| `rgbww/+/monitor` | Device telemetry data | `rgbww_debug_data` measurement |
| `rgbww/+/log` | Device log messages | `rgbww_log` measurement |

### InfluxDB Measurements

- **rgbww_debug_data**: Device telemetry with device ID tags
  - Fields: `uptime`, `freeHeap`, `mdns_received`, etc.
  - Tags: `device` (chip ID)
- **rgbww_log**: Device log messages  
  - Fields: `message` (log content)
  - Tags: `id` (chip ID)

### Pre-configured Dashboards

- **📋 Device Overview**: Complete inventory with status, memory, uptime
- **📝 Device Logs**: Centralized log viewer with filtering by device
- **📈 Historical Trends**: Time-series analysis of device metrics
- **⚠️ Alerting**: Built-in alerts for device issues

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   IoT Devices   │    │  MQTT JSON       │    │   InfluxDB      │
│                 │    │  Bridge          │    │                 │
│ MQTT telemetry  │───►│                  │───►│ Time-series     │
│ MQTT logs       │    │ Flattens JSON    │    │ storage         │
│                 │    │ Device ID tags   │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                ▲                        ▲
                                │                        │
                                ▼                        │
                      HTTP Metrics Endpoint              │
                      (http://localhost:8001)            │
                                                         ▼
                                                ┌─────────────────┐
                                                │    Grafana      │
                                                │   Dashboards    │
                                                └─────────────────┘
```

## 📁 Project Structure

```
rgbww-monitoring-project/
├── README.md                    # This file
├── LICENSE                      # License information  
├── CHANGELOG.md                 # Version history
├── rgbww-importer/              # Unified MQTT JSON bridge
│   ├── mqtt-json-bridge.py     # Main bridge application
│   ├── config.ini              # Example configuration
│   ├── install.sh              # Local installer
│   └── README.md               # Bridge documentation
├── containerized/              # Docker deployment
│   ├── docker-compose.yml      # Multi-service orchestration
│   ├── Dockerfile.influxdb_importer # Updated importer image
│   ├── rgbww-importer-config.ini    # Container configuration
│   └── grafana/                # Grafana with dashboards
└── native-install/             # Native system installation
    ├── install.sh              # Native installer
    ├── uninstall.sh            # Complete removal
    └── README.md               # Native install docs
```

## 🔧 Configuration

### MQTT Settings
```ini
[mqtt]
broker = your-mqtt-broker.com
port = 1883
username = your-username
password = your-password
stats_topic = rgbww/+/monitor
log_topic = rgbww/+/log
```

### InfluxDB Settings
```ini
[influxdb]
url = http://localhost:8086        # For native
# url = http://influxdb:8086       # For containers  
org = your-organization
bucket = rgbww
token = your-influxdb-token
```

## 🛠️ Installation Guide

### Prerequisites

**For Containerized:**
- Docker and Docker Compose
- MQTT broker access
- InfluxDB token (generated during setup)

**For Native:**
- Linux system with systemd
- Python 3.7+
- MQTT broker access
- Local or remote InfluxDB instance

### Containerized Setup

```bash
# 1. Clone repository
git clone <repository-url>
cd rgbww-monitoring-project/containerized/

# 2. Configure MQTT and InfluxDB settings
cp rgbww-importer-config.ini.example rgbww-importer-config.ini
nano rgbww-importer-config.ini

# 3. Start services
docker-compose up -d

# 4. Access Grafana at http://localhost:3000 (admin/rgbww123)
# 5. Get InfluxDB token from http://localhost:8086
```

### Native Installation

```bash
# 1. Clone repository
git clone <repository-url>
cd rgbww-monitoring-project/native-install/

# 2. Run installer
sudo ./install.sh

# 3. Configure bridge
sudo nano /etc/rgbww-bridge/config.ini

# 4. Start service
sudo systemctl enable rgbww-bridge
sudo systemctl start rgbww-bridge

# 5. Check status
sudo systemctl status rgbww-bridge
```

## 📈 Usage Examples

### Service Management

```bash
# Native installation
sudo systemctl status rgbww-bridge
sudo journalctl -u rgbww-bridge -f
sudo systemctl restart rgbww-bridge

# Containerized
docker-compose logs -f influxdb_importer
docker-compose restart influxdb_importer
docker-compose ps
```

### HTTP Metrics Endpoint

```bash
# Check collected metrics
curl http://localhost:8001/metrics.json

# View with formatting
curl -s http://localhost:8001/metrics.json | python3 -m json.tool
```

### InfluxDB Flux Queries

```flux
// Get all device logs
from(bucket: "rgbww")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "rgbww_log")

// Get device telemetry for specific device
from(bucket: "rgbww")
  |> range(start: -1h)
  |> filter(fn: (r) => 
      r._measurement == "rgbww_debug_data" and
      r.device == "123456"
  )
```

## 🔍 Troubleshooting

### Common Issues

**Bridge not connecting to MQTT:**
- Check broker connectivity: `telnet mqtt-broker 1883`
- Verify credentials in configuration
- Check firewall rules

**No data in InfluxDB:**
- Verify InfluxDB token and permissions
- Check bucket name and organization
- Test InfluxDB connectivity

**Service crashes:**
- Check logs: `journalctl -u rgbww-bridge`
- Verify Python dependencies
- Check configuration file syntax

### Log Analysis

```bash
# Native installation logs
sudo journalctl -u rgbww-bridge --since "1 hour ago"
sudo journalctl -u rgbww-bridge | grep -i error

# Container logs
docker-compose logs influxdb_importer --since 1h
docker-compose logs influxdb_importer | grep ERROR
```

## 🎨 Customization

### Adding Custom Fields

Edit the bridge configuration to handle additional MQTT topics or modify JSON processing for new device fields.

### Custom Dashboards

1. Create dashboard in Grafana UI
2. Export JSON
3. Save to `grafana/dashboards/` directory  
4. Restart Grafana container

### Buffer and Performance Tuning

```ini
[application]
buffer_size = 20        # Increase for high-volume environments
write_interval = 10     # Adjust write frequency
http_port = 8001       # Change if port conflicts
```

## 🚀 Production Deployment

### Security Considerations

- Use TLS for MQTT connections
- Secure InfluxDB with proper authentication
- Configure Grafana with HTTPS and strong passwords
- Use network segmentation for IoT devices
- Regular backup of InfluxDB data

### High Availability

- Use InfluxDB clustering for redundancy
- Configure Grafana with external database
- Deploy multiple bridge instances with load balancing
- Implement health checks and monitoring

### Performance Optimization

- Tune InfluxDB retention policies
- Configure appropriate shard durations
- Monitor system resources (CPU, memory, disk)
- Use SSD storage for InfluxDB

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test changes with both deployment methods
4. Update documentation as needed
5. Submit pull request

### Development Setup

```bash
# Test native installation
cd native-install/
sudo ./install.sh

# Test containerized deployment  
cd containerized/
docker-compose up -d
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎉 Acknowledgments

- InfluxDB community for excellent time-series database
- Grafana team for beautiful visualization platform
- Paho MQTT Python client for reliable MQTT connectivity
- RGBWW IoT device developers for providing MQTT interfaces

## 📞 Support

- **Documentation**: See individual README files in each directory
- **Issues**: Report bugs via GitHub issues  
- **Configuration Help**: Check troubleshooting section
- **MQTT Topics**: Ensure devices publish to `rgbww/{device_id}/monitor` and `rgbww/{device_id}/log`

---

**🚀 Ready to monitor your IoT devices? Choose your deployment method and get started!**