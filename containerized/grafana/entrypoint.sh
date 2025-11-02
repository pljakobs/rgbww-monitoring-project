#!/bin/bash

# Custom Grafana entrypoint
# Starts Grafana and then configures datasources and dashboards

set -e

echo "🚀 Starting Grafana..."

export INFLUXDB_TOKEN="${INFLUXDB_TOKEN}"

# Start Grafana in background
/run.sh "$@" &
GRAFANA_PID=$!

# Wait a bit for Grafana to start
sleep 10

# Run setup script
echo "🔧 Running Grafana setup..."
/usr/local/bin/setup-grafana.sh

# Wait for Grafana process
wait $GRAFANA_PID