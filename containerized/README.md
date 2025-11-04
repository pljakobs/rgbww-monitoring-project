# 🎯 RGBWW IoT Monitoring Stack

**One-command deployment** of a complete IoT monitoring solution with MQTT data collection, InfluxDB storage, and beautiful Grafana dashboards.

## ✨ What You Get

- **� MQTT Data Collection**: Collects telemetry and log data from RGBWW IoT devices
- **� InfluxDB Storage**: Time-series database for efficient metric storage
- **� Grafana Dashboards**: Pre-configured dashboards for device monitoring
- **🔧 Configurable Importer**: Flexible MQTT-to-InfluxDB bridge with external config
- **📋 Device Logs**: Centralized log collection and analysis
- **⚡ Real-time Metrics**: Live device telemetry and status monitoring

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- MQTT broker with RGBWW device data
- InfluxDB token (generated during setup)

### Configuration Setup

1. **Copy and customize the config file:**
   ```bash
   cp rgbww-importer-config.ini.example rgbww-importer-config.ini
   # Edit the config file with your settings
   ```

2. **Update MQTT settings in `rgbww-importer-config.ini`:**
   ```ini
   [mqtt]
   broker = your-mqtt-broker.com
   username = your-username
   password = your-password
   ```

3. **Set InfluxDB token after initial setup:**
   ```bash
   # Start services first to generate InfluxDB
   docker-compose up -d influxdb
   
   # Get token from InfluxDB UI at http://localhost:8086
   # Update rgbww-importer-config.ini with the token
   ```

### One-Command Deployment

```bash
# Start all services
docker-compose up -d
```

That's it! The system will:
1. ✅ Start InfluxDB with persistent storage
2. ✅ Start Grafana with pre-configured dashboards  
3. ✅ Start MQTT importer with your config
4. ✅ Begin collecting device data automatically

## 📊 Access Your Monitoring

### Grafana Dashboards
- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: `rgbww123`

### Prometheus
- **URL**: http://localhost:9090

### JSON Exporter
- **URL**: http://localhost:7979

## 🎨 Pre-configured Dashboards

### 1. Controller Status Dashboard
**Streamlined controller monitoring with essential metrics**

- 📋 **Controller Status Table**: One line per controller showing:
  - Controller name and device ID
  - Online/offline status with color coding
  - Current uptime in human-readable format
  - Free heap memory with gauge visualization
  - ROM version and SoC information
- 📈 **Free Heap Time Series**: Real-time memory monitoring graph
  - Individual line per controller
  - Legend with current, min, and max values
  - Color-coded by controller for easy identification

### 2. RGBWW IoT Device Overview
**Complete device inventory and status monitoring**

- 📊 **Device Statistics**: Total devices, online ratio, average uptime
- 📈 **ROM Version Distribution**: Pie chart of firmware versions
- 📋 **Device Inventory Table**: Complete device details with status
- 💾 **Memory Usage Graphs**: Real-time heap memory monitoring
- ⏱️ **Uptime Tracking**: Device uptime over time

### 3. RGBWW Network Topology  
**Network visualization and connectivity monitoring**

- 🗺️ **Network Map**: Geographic view of device locations
- 📍 **IP Distribution**: Device count by subnet
- 🔗 **Connectivity Status**: Real-time connection monitoring
- 📡 **Network Health**: Historical connectivity patterns

## 🔧 Device Discovery

### Initial Discovery Setup

The system needs a starting point to discover your IoT devices. You have three options:

**🎯 Method 1: Known Controller (Recommended)**
```bash
export INITIAL_CONTROLLER_IP=192.168.1.100
./rgbww-monitor.sh start
```
- Fastest and most reliable
- Uses one known device to discover the entire network
- Recommended if you know any device IP

**🌐 Method 2: Network Range Scan**
```bash
export NETWORK_RANGE=192.168.1.0/24  
./rgbww-monitor.sh start
```
- Scans entire network range for IoT devices
- Takes longer but finds devices automatically
- Good for completely unknown networks

**🔧 Method 3: Manual Addition**
```bash
# Start without initial discovery
./rgbww-monitor.sh start

# Then manually add devices via container
docker-compose exec prometheus /etc/prometheus/manage-iot-devices.sh add 192.168.1.100
```

### How Discovery Works

The system automatically discovers devices by:

1. **Initial Scan**: Network discovery or manual device seed
2. **Topology Crawling**: Queries `/hosts` endpoint on each device
3. **Multi-Round Discovery**: Continues until no new devices found
4. **Metadata Collection**: Fetches device names from `/config`
5. **Stable IDs**: Uses device IDs from `/info` as primary keys

### Monitored Endpoints

| Endpoint | Purpose | Data Extracted |
|----------|---------|----------------|
| `/info` | Device status | `uptime`, `heap_free`, `deviceid`, `current_rom`, `git_version` |
| `/config` | Device configuration | `device_name` |
| `/hosts` | Network topology | IP addresses of other devices |

## 📈 Available Metrics

```promql
# Device information with labels
device_info{deviceid="...", device_name="...", current_rom="...", git_version="...", ip="..."}

# Device uptime in seconds  
device_uptime_seconds{deviceid="..."}

# Free heap memory in bytes
device_heap_free_bytes{deviceid="..."}

# Connection status (1=online, 0=offline)
device_connected{deviceid="..."}
```

## 🛠️ Management Commands

```bash
# Start the stack
./rgbww-monitor.sh start

# Stop all services
./rgbww-monitor.sh stop

# Restart services
./rgbww-monitor.sh restart

# View live logs
./rgbww-monitor.sh logs

# Check service status
./rgbww-monitor.sh status
```

### Docker Compose Commands

```bash
# Manual container management
docker-compose up -d          # Start in background
docker-compose down           # Stop and remove
docker-compose logs -f        # Follow logs
docker-compose ps             # Service status
docker-compose restart       # Restart services
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   IoT Devices   │    │   JSON Exporter  │    │   Prometheus    │
│                 │    │   (Port 7979)    │    │   (Port 9090)   │
│ /info endpoint  │◄───┤ Queries devices  │◄───┤ Scrapes metrics │
│ /config endpoint│    │ Converts JSON    │    │ Stores data     │
│ /hosts endpoint │    │ to metrics       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                 ▲                        ▲
                                 │                        │
                                 └────────────────────────┴──────┐
                                        Discovery Script         │
                                        (30min timer)            │
                                                                 ▼
                                                    ┌─────────────────┐
                                                    │    Grafana      │
                                                    │  (Port 3000)    │
                                                    │   Dashboards    │
                                                    └─────────────────┘
```

## 📁 Container Structure

```
rgbww-container/
├── docker-compose.yml          # Multi-service orchestration
├── rgbww-monitor.sh           # One-command deployment script
├── README.md                  # This documentation
├── prometheus/
│   ├── Dockerfile            # Custom Prometheus image
│   ├── prometheus.yml        # Prometheus configuration
│   ├── manage-iot-devices.sh # Device discovery script
│   └── entrypoint.sh         # Container startup script
├── json-exporter/
│   ├── Dockerfile            # JSON Exporter image
│   └── json_exporter.yml     # JSON to metrics config
└── grafana/
    ├── provisioning/
    │   ├── datasources/      # Prometheus datasource config
    │   └── dashboards/       # Dashboard provisioning
    └── dashboards/
        ├── iot-overview.json     # Main IoT dashboard
        └── network-topology.json # Network visualization
```

## 🔍 Troubleshooting

### No Devices Discovered

```bash
# Check discovery logs
docker-compose logs prometheus

# Manual device discovery
docker-compose exec prometheus /etc/prometheus/manage-iot-devices.sh discover

# Test device connectivity
curl http://<device-ip>/info
```

### Services Not Starting

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs <service-name>

# Restart specific service
docker-compose restart <service-name>
```

### Dashboard Not Loading

```bash
# Check Grafana logs
docker-compose logs grafana

# Verify Prometheus connection
curl http://localhost:9090/-/ready

# Reset Grafana admin password
docker-compose exec grafana grafana-cli admin reset-admin-password rgbww123
```

### Port Conflicts

If default ports are in use, edit `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Change Grafana port
  - "9091:9090"  # Change Prometheus port  
  - "7980:7979"  # Change JSON Exporter port
```

## ⚙️ Environment Variables

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `INITIAL_CONTROLLER_IP` | IP of one known IoT device | `192.168.1.100` | Recommended |
| `NETWORK_RANGE` | Network range to scan | `192.168.1.0/24` | Alternative |
| `PROMETHEUS_RETENTION_TIME` | Data retention period | `15d` | No |
| `PROMETHEUS_RETENTION_SIZE` | Max storage size | `10GB` | No |

### Example with Environment Variables

```bash
# Complete setup with custom retention
export INITIAL_CONTROLLER_IP=192.168.1.100
export PROMETHEUS_RETENTION_TIME=30d
export PROMETHEUS_RETENTION_SIZE=20GB
./rgbww-monitor.sh start
```

## 🔧 Customization

### Adding Custom Dashboards

1. Create dashboard in Grafana UI
2. Export JSON
3. Save to `grafana/dashboards/`
4. Restart Grafana: `docker-compose restart grafana`

### Modifying Discovery Interval

Edit `prometheus/entrypoint.sh`:
```bash
sleep 900  # Change from 1800 (30min) to 900 (15min)
```

### Custom Metrics

Edit `json-exporter/json_exporter.yml` to add new metrics from device endpoints.

## 📊 Example Queries

```promql
# Devices with low memory
device_heap_free_bytes < 10240

# Average uptime by ROM version
avg by (current_rom) (device_uptime_seconds)

# Device connectivity over time
rate(device_connected[5m])

# Devices by network subnet
count by (ip) (device_info)
```

## 💾 Data Persistence

- **Prometheus Data**: Stored in `prometheus_data` volume
- **Grafana Settings**: Stored in `grafana_data` volume
- **Data Retention**: 15 days (configurable in docker-compose.yml)

## 🔒 Security

- Grafana admin password: `rgbww123` (change in docker-compose.yml)
- Anonymous viewing enabled for dashboards
- No external authentication configured (add if needed)

## 🚀 Production Deployment

For production use:

1. **Change default passwords**
2. **Configure HTTPS/TLS**
3. **Set up external authentication**
4. **Configure alerting**
5. **Set up backup for volumes**
6. **Use specific image tags**

## 📝 License

This monitoring stack is provided as-is for RGBWW IoT device monitoring. Modify and distribute freely.

---

## 🤝 Support

**Quick Help:**
1. Check logs: `./rgbww-monitor.sh logs`
2. Verify device connectivity: `curl http://<device>/info`
3. Check service status: `./rgbww-monitor.sh status`
4. Restart services: `./rgbww-monitor.sh restart`

For advanced configuration and troubleshooting, see the individual component documentation in each service directory.