# 🎯 RGBWW IoT Device Monitoring System

A comprehensive monitoring solution for RGBWW IoT devices with automatic network discovery, Prometheus metrics collection, and Grafana dashboards.

## ✨ Features

- **🔍 Automatic Device Discovery**: Network topology crawling via `/hosts` endpoints
- **🔑 Stable Device IDs**: Uses device IDs as primary keys for consistent metrics
- **📊 Prometheus Integration**: Collects metrics from device `/info` endpoints  
- **📈 Grafana Dashboards**: Pre-configured dashboards for monitoring and visualization
- **🌐 Network Topology Mapping**: Discovers entire device networks automatically
- **⚡ Automated Scheduling**: 30-minute discovery intervals
- **📦 Multiple Deployment Options**: Native installation or containerized

## 🚀 Quick Start

### Option 1: Native Installation (Recommended for LXC/Limited Environments)

```bash
cd native-install/
sudo ./install.sh
```

### Option 2: Containerized (Docker/Podman)

```bash
cd containerized/
export INITIAL_CONTROLLER_IP=192.168.1.100  # Your IoT device IP
./rgbww-monitor.sh start
```

## 📊 What You Get

### Monitored Metrics

| Metric | Description | Labels |
|--------|-------------|---------|
| `device_info` | Static device information | `deviceid`, `device_name`, `current_rom`, `git_version`, `ip` |
| `device_uptime_seconds` | Device uptime in seconds | `deviceid` |
| `device_heap_free_bytes` | Available heap memory | `deviceid` |
| `device_connected` | Connection status (1=online, 0=offline) | `deviceid` |

### Pre-configured Dashboards

- **📋 Device Overview**: Complete inventory with status, memory, uptime
- **🗺️ Network Topology**: Geographic and network visualization
- **📈 Historical Trends**: Time-series analysis of device metrics
- **⚠️ Alerting**: Built-in alerts for offline devices and low memory

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   IoT Devices   │    │   JSON Exporter  │    │   Prometheus    │
│                 │    │                  │    │                 │
│ /info endpoint  │◄───┤ Queries devices  │◄───┤ Scrapes metrics │
│ /config endpoint│    │ Converts JSON    │    │ Stores data     │
│ /hosts endpoint │    │ to metrics       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         ▲                        ▲                        ▲
         │                        │                        │
         └────────────────────────┴────────────────────────┴──────┐
                            Discovery Script (30min timer)         │
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
├── LICENSE                      # MIT License
├── CHANGELOG.md                 # Version history
├── native-install/              # Native system installation
│   ├── install.sh              # One-command installer
│   ├── uninstall.sh            # Complete removal
│   ├── config/                 # Configuration files
│   ├── systemd/                # Service definitions
│   └── scripts/                # Management scripts
└── containerized/              # Docker/Podman deployment
    ├── docker-compose.yml      # Multi-service orchestration
    ├── rgbww-monitor.sh        # Container management script
    ├── prometheus/             # Custom Prometheus image
    ├── json-exporter/          # JSON Exporter image
    └── grafana/                # Grafana with dashboards
```

## 🔧 Device Discovery

### How It Works

1. **Initial Seed**: Starts with one known device IP or network scan
2. **Topology Crawling**: Queries `/hosts` endpoint on each discovered device
3. **Multi-Round Discovery**: Continues until no new devices are found
4. **Metadata Collection**: Fetches device names from `/config` endpoint
5. **Stable Identification**: Uses device IDs from `/info` as primary keys

### Device Endpoints

| Endpoint | Purpose | Data Extracted |
|----------|---------|----------------|
| `/info` | Device status | `uptime`, `heap_free`, `deviceid`, `current_rom`, `git_version` |
| `/config` | Device configuration | `device_name` |
| `/hosts` | Network topology | IP addresses of connected devices |

## 🛠️ Installation Guide

### Prerequisites

**For Native Installation:**
- Linux system with systemd
- Root access
- Network access to IoT devices
- Dependencies: `curl`, `jq` (auto-installed)

**For Containerized:**
- Docker or Podman with docker-compose
- Ports 3000, 7979, 9090 available
- Initial controller IP or network range

### Native Installation

```bash
# Clone the repository
git clone https://github.com/your-username/rgbww-monitoring.git
cd rgbww-monitoring/native-install/

# Run installer
sudo ./install.sh

# Check status
sudo systemctl status json_exporter iot-discovery.timer
```

### Containerized Installation

```bash
# Clone and setup
git clone https://github.com/your-username/rgbww-monitoring.git
cd rgbww-monitoring/containerized/

# Configure initial controller
export INITIAL_CONTROLLER_IP=192.168.1.100

# Start stack
./rgbww-monitor.sh start

# Access Grafana: http://localhost:3000 (admin/rgbww123)
```

## 📈 Usage Examples

### Manual Device Management

```bash
# Add device manually
sudo /etc/prometheus/manage-iot-devices.sh add 192.168.1.100

# Discover all devices from one known device
sudo /etc/prometheus/manage-iot-devices.sh discover 192.168.1.100

# List all discovered devices
sudo /etc/prometheus/manage-iot-devices.sh list

# Check system status
sudo /etc/prometheus/iot-status.sh
```

### Prometheus Queries

```promql
# Devices with low memory
device_heap_free_bytes < 10240

# Average uptime by ROM version
avg by (current_rom) (device_uptime_seconds)

# Device connectivity over time
rate(device_connected[5m])

# Count devices by network
count by (ip) (device_info)
```

## 🔍 Troubleshooting

### Common Issues

**No devices discovered:**
- Check network connectivity: `curl http://<device-ip>/info`
- Verify initial controller IP is reachable
- Check discovery logs: `journalctl -u iot-discovery.service`

**JSON Exporter not working:**
- Test configuration: `systemctl status json_exporter`
- Check device endpoints return valid JSON
- Verify port 7979 is accessible

**Grafana dashboards not loading:**
- Check Prometheus connection in Grafana data sources
- Verify metrics are being collected: `curl http://localhost:9090/api/v1/query?query=device_info`

### Log Locations

- **Discovery**: `journalctl -u iot-discovery.service`
- **JSON Exporter**: `journalctl -u json_exporter`
- **Prometheus**: `journalctl -u prometheus`
- **Installation**: `/tmp/rgbww-install.log`

## 🎨 Customization

### Adding Custom Metrics

Edit `/etc/prometheus/json_exporter.yml` to extract additional fields from device endpoints.

### Custom Dashboards

1. Create dashboard in Grafana
2. Export JSON
3. Save to `grafana/dashboards/` directory
4. Restart Grafana

### Discovery Interval

```bash
# Change discovery frequency
sudo systemctl edit iot-discovery.timer

# Add:
[Timer]
OnCalendar=
OnCalendar=*:0/15  # Every 15 minutes
```

## 🚀 Production Deployment

### Security Recommendations

- Change default Grafana password
- Configure HTTPS/TLS certificates
- Set up authentication (LDAP/OAuth)
- Configure firewall rules
- Set up log rotation

### High Availability

- Use external Prometheus storage
- Configure Grafana with external database
- Set up backup automation
- Use load balancer for Grafana

### Monitoring

- Set up alerting rules
- Configure notification channels
- Monitor system resource usage
- Set up external health checks

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit pull request

### Development Setup

```bash
# Local development
cd native-install/
sudo ./install.sh

# Test changes
sudo /etc/prometheus/manage-iot-devices.sh discover
sudo /etc/prometheus/iot-status.sh
```

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

**Copyleft Notice**: This is free software under a copyleft license. Any derivative works must also be released under GPL v3 or later, ensuring that improvements remain free and open source for the community.

## 🎉 Acknowledgments

- Prometheus community for excellent monitoring tools
- Grafana team for beautiful visualization platform
- JSON Exporter for flexible metric conversion
- RGBWW IoT device developers for providing accessible APIs

## 📞 Support

- **Documentation**: See individual README files in each deployment directory
- **Issues**: Report bugs via GitHub issues
- **Discussions**: Use GitHub discussions for questions
- **Quick Help**: Check troubleshooting section above

---

**🚀 Ready to monitor your IoT devices? Choose your deployment method and get started!**