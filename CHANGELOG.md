# Changelog

All notable changes to the RGBWW IoT Device Monitoring System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-24

### Added
- **Complete IoT device monitoring system**
- **Automatic device discovery** via network topology crawling
- **Device ID-based primary keys** for stable metrics across IP changes
- **Multi-round network discovery** through `/hosts` endpoint queries
- **Prometheus integration** with JSON Exporter for metrics collection
- **Pre-configured Grafana dashboards** for device overview and network topology
- **30-minute automated discovery** with systemd timer
- **Native installation package** with one-command deployment
- **Containerized deployment** with Docker Compose support
- **Device metadata collection** from `/config` endpoints
- **Comprehensive management scripts** for device administration

### Features
- Monitors device uptime, heap memory, connection status, ROM versions
- Network topology visualization and IP distribution tracking  
- Device inventory table with real-time status updates
- Historical trending of device metrics over time
- Automated log rotation and system health monitoring
- Complete installation and uninstallation scripts
- Production-ready systemd service integration

### Supported Endpoints
- `/info` - Device status, uptime, memory, device ID, ROM version, git version
- `/config` - Device configuration and friendly names
- `/hosts` - Network topology for peer device discovery

### Deployment Options
- **Native Installation**: Direct system installation with systemd services
- **Containerized**: Docker/Podman deployment with orchestration
- **Hybrid**: Mix of containerized and native components

### Documentation
- Complete installation guides for both deployment methods
- Troubleshooting guides and common issue resolution
- Prometheus query examples and dashboard customization
- Production deployment recommendations
- Security and high availability guidance

### Known Issues
- Containerized version requires full container privileges (not suitable for LXC)
- Network scanning requires `nmap` for automatic device discovery
- Some routers may block rapid network scanning requests

### Dependencies
- **Native**: systemd, curl, jq, Prometheus, JSON Exporter
- **Containerized**: Docker/Podman, docker-compose
- **Optional**: nmap for network scanning