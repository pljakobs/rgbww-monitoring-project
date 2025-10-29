#!/bin/bash
# Script to create InfluxDB token and store as Podman secret
set -e

# InfluxDB connection details
INFLUXDB_URL="http://localhost:8086"
INFLUXDB_USER="admin"
INFLUXDB_PASS="rgbww123"
INFLUXDB_ORG="default"
INFLUXDB_BUCKET="rgbww"
SECRET_NAME="influxdb-token"


# Create MQTT Importer token inside InfluxDB container
MQTT_TOKEN=$(podman exec rgbww-influxdb influx auth create --org "$INFLUXDB_ORG" --read-buckets --write-buckets --user "$INFLUXDB_USER" --description "MQTT Importer Token" --json | jq -r '.token')
# Create Grafana token inside InfluxDB container
GRAFANA_TOKEN=$(podman exec rgbww-influxdb influx auth create --org "$INFLUXDB_ORG" --read-buckets --write-buckets --user "$INFLUXDB_USER" --description "Grafana Token" --json | jq -r '.token')

echo "$MQTT_TOKEN" | podman secret create influxdb-token-mqtt -
echo "$GRAFANA_TOKEN" | podman secret create influxdb-token-grafana -
echo "✅ MQTT Importer token stored as Podman secret: influxdb-token-mqtt"
echo "✅ Grafana token stored as Podman secret: influxdb-token-grafana"

# Export tokens for use in deployment

echo "export INFLUXDB_TOKEN_MQTT='$MQTT_TOKEN'" > influxdb-tokens.env
echo "export INFLUXDB_TOKEN_GRAFANA='$GRAFANA_TOKEN'" >> influxdb-tokens.env
echo "✅ MQTT Importer token exported to influxdb-tokens.env as INFLUXDB_TOKEN_MQTT"
echo "✅ Grafana token exported to influxdb-tokens.env as INFLUXDB_TOKEN_GRAFANA"

# Add static token for Telegraf usage
echo "export INFLUX_TOKEN=9P4GQHms5VSmiIDtqOoJUBiH5bhzCU0AxZMN8r3g7HXZfOAqgY5DxgYTXe4B4sEio3nBTFjSXDNZpgPwfh9K3A==" >> influxdb-tokens.env
