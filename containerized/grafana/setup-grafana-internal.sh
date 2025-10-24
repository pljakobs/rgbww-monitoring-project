#!/bin/bash

# Internal Grafana setup script (runs inside container)
set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="${GF_SECURITY_ADMIN_PASSWORD:-rgbww123}"

echo "🎯 Setting up Grafana datasource and dashboards..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
for i in {1..60}; do
    if curl -s -f "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
        echo "✅ Grafana is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Grafana failed to start within timeout"
        exit 1
    fi
    sleep 2
done

# Add Prometheus datasource with specific UID
echo "📊 Adding Prometheus datasource..."
DATASOURCE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d '{
  "uid": "prometheus",
  "name": "Prometheus",
  "type": "prometheus", 
  "url": "http://prometheus:9090",
  "access": "proxy",
  "isDefault": true
}' "http://$GRAFANA_USER:$GRAFANA_PASS@localhost:3000/api/datasources" 2>/dev/null)

if echo "$DATASOURCE_RESPONSE" | grep -q "Datasource added\|already exists\|data source with the same name or uid already exists"; then
    echo "✅ Prometheus datasource configured"
else
    echo "⚠️  Datasource response: $DATASOURCE_RESPONSE"
fi

# Import all dashboards
echo "📈 Importing dashboards..."
for dashboard_file in /var/lib/grafana/dashboards/*.json; do
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
            "http://$GRAFANA_USER:$GRAFANA_PASS@localhost:3000/api/dashboards/db")
        
        if echo "$import_response" | grep -q '"status":"success"'; then
            echo "   ✅ Successfully imported: $dashboard_name"
        else
            echo "   ⚠️  Import response for $dashboard_name: $import_response"
        fi
        
        rm "$temp_file"
    fi
done

echo "🎉 Grafana setup complete!"