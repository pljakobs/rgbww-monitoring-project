#!/bin/bash

# Grafana Setup Script
# Configures datasource and imports dashboards via API

set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="rgbww123"
GRAFANA_AUTH="$GRAFANA_USER:$GRAFANA_PASS"

# Directory containing dashboard JSON files
DASHBOARD_DIR="$(dirname "$0")/grafana/dashboards"

echo "🎯 Setting up Grafana..."
echo "📍 Grafana URL: $GRAFANA_URL"

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
for i in {1..30}; do
    if curl -s -f "$GRAFANA_URL/api/health" > /dev/null; then
        echo "✅ Grafana is ready!"
        break
    fi
    echo "   Attempt $i/30 - waiting..."
    sleep 2
done

# Add Prometheus datasource
echo "📊 Adding Prometheus datasource..."
DATASOURCE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{
  "name": "Prometheus",
  "type": "prometheus", 
  "url": "http://prometheus:9090",
  "access": "proxy",
  "isDefault": true
}' "http://$GRAFANA_AUTH@localhost:3000/api/datasources" 2>/dev/null)

if echo "$DATASOURCE_RESPONSE" | grep -q "Datasource added\|already exists"; then
    echo "✅ Prometheus datasource configured"
else
    echo "⚠️  Datasource response: $DATASOURCE_RESPONSE"
fi

# Import all dashboards
echo "📈 Importing dashboards..."

if [ ! -d "$DASHBOARD_DIR" ]; then
    echo "❌ Dashboard directory not found: $DASHBOARD_DIR"
    exit 1
fi

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
    if [ -f "$dashboard_file" ]; then
        dashboard_name=$(basename "$dashboard_file" .json)
        echo "   📋 Importing: $dashboard_name"
        
        # Create properly formatted import JSON
        temp_file=$(mktemp)
        echo '{"dashboard":' > "$temp_file"
        cat "$dashboard_file" >> "$temp_file" 
        echo ',"overwrite":true}' >> "$temp_file"
        
        # Import dashboard
        import_response=$(curl -s -X POST -H "Content-Type: application/json" \
            -d @"$temp_file" \
            "http://$GRAFANA_AUTH@localhost:3000/api/dashboards/db")
        
        if echo "$import_response" | grep -q '"status":"success"'; then
            echo "   ✅ Successfully imported: $dashboard_name"
        else
            echo "   ⚠️  Import response for $dashboard_name: $import_response"
        fi
        
        rm "$temp_file"
    fi
done

echo ""
echo "🎉 Grafana setup complete!"
echo ""  
echo "📊 Access your dashboards at:"
echo "   🔗 $GRAFANA_URL"
echo "   👤 Username: $GRAFANA_USER"
echo "   🔐 Password: $GRAFANA_PASS"
echo ""
echo "📋 Available dashboards:"
echo "   • Controller Status Dashboard - /d/rgbww-controller-status/controller-status-dashboard"
echo "   • RGBWW IoT Device Overview - /d/rgbww-iot-overview/rgbww-iot-device-overview"  
echo "   • RGBWW Network Topology - /d/rgbww-network-topology/rgbww-network-topology"
echo ""