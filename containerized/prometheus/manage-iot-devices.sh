#!/bin/bash

# IoT Device Manager for Prometheus
# This script helps manage the list of IoT devices in prometheus.yml

PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
PROMETHEUS_TEMPLATE="/etc/prometheus/prometheus.yml.template"
DEVICES_FILE="/etc/prometheus/iot-devices.txt"
DEVICE_METADATA="/etc/prometheus/iot-device-metadata.json"

# Function to add a device
add_device() {
    local device_ip="$1"
    if [ -z "$device_ip" ]; then
        echo "Usage: $0 add <device_ip>"
        exit 1
    fi
    
    # Check if device already exists
    if grep -q "^$device_ip$" "$DEVICES_FILE" 2>/dev/null; then
        echo "Device $device_ip already exists"
        return 1
    fi
    
    echo "Adding device: $device_ip"
    echo "Fetching device configuration..."
    
    # Fetch device metadata from both config and info endpoints
    local config_data=""
    local info_data=""
    local device_name="unknown"
    local deviceid="unknown"
    
    if command -v curl >/dev/null 2>&1; then
        # Get config data for device name
        config_data=$(curl -s --connect-timeout 10 "http://$device_ip/config" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$config_data" ]; then
            if command -v jq >/dev/null 2>&1; then
                device_name=$(echo "$config_data" | jq -r '.general.device_name // .network.mdns.name // .device_name // .name // "unknown"' 2>/dev/null)
            else
                # Fallback without jq - basic grep for general.device_name
                device_name=$(echo "$config_data" | grep -o '"device_name"[^"]*"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
            fi
        fi
        
        # Get info data for device ID  
        info_data=$(curl -s --connect-timeout 10 "http://$device_ip/info" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$info_data" ]; then
            if command -v jq >/dev/null 2>&1; then
                deviceid=$(echo "$info_data" | jq -r '.deviceid // "unknown"' 2>/dev/null)
            else
                # Fallback without jq
                deviceid=$(echo "$info_data" | grep -o '"deviceid"[^"]*"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
            fi
        fi
    fi
    
    # Initialize metadata file if it doesn't exist
    if [ ! -f "$DEVICE_METADATA" ]; then
        echo "{}" > "$DEVICE_METADATA"
    fi
    
    # Add device metadata using jq if available, otherwise append to simple format
    if command -v jq >/dev/null 2>&1; then
        # Update JSON metadata file
        local temp_meta=$(mktemp)
        jq --arg ip "$device_ip" --arg name "$device_name" --arg id "$deviceid" \
           '.[$ip] = {device_name: $name, deviceid: $id, added_date: now | strftime("%Y-%m-%d %H:%M:%S")}' \
           "$DEVICE_METADATA" > "$temp_meta" && mv "$temp_meta" "$DEVICE_METADATA"
    else
        # Fallback to simple format
        echo "$device_ip|$device_name|$deviceid|$(date)" >> "${DEVICE_METADATA}.simple"
    fi
    
    # Add to devices list
    echo "$device_ip" >> "$DEVICES_FILE"
    
    echo "Device added successfully:"
    echo "  IP: $device_ip"
    echo "  Name: $device_name"
    echo "  Device ID: $deviceid"
    
    update_prometheus_config
}

# Function to remove a device
remove_device() {
    local device_ip="$1"
    if [ -z "$device_ip" ]; then
        echo "Usage: $0 remove <device_ip>"
        exit 1
    fi
    
    # Remove from devices list
    sed -i "/^$device_ip$/d" "$DEVICES_FILE"
    
    # Remove from metadata
    if [ -f "$DEVICE_METADATA" ] && command -v jq >/dev/null 2>&1; then
        local temp_meta=$(mktemp)
        jq --arg ip "$device_ip" 'del(.[$ip])' "$DEVICE_METADATA" > "$temp_meta" && mv "$temp_meta" "$DEVICE_METADATA"
    elif [ -f "${DEVICE_METADATA}.simple" ]; then
        sed -i "/^$device_ip|/d" "${DEVICE_METADATA}.simple"
    fi
    
    echo "Removed device: $device_ip"
    update_prometheus_config
}

# Function to list devices
list_devices() {
    echo "Current IoT devices:"
    if [ ! -f "$DEVICES_FILE" ]; then
        echo "No devices configured"
        return
    fi
    
    echo "IP Address       | Device Name            | Device ID"
    echo "-----------------|------------------------|----------"
    
    while IFS= read -r device_ip; do
        [ -z "$device_ip" ] && continue
        
        local device_name="unknown"
        local deviceid="unknown"
        
        # Get metadata if available
        if [ -f "$DEVICE_METADATA" ] && command -v jq >/dev/null 2>&1; then
            device_name=$(jq -r --arg ip "$device_ip" '.[$ip].device_name // "unknown"' "$DEVICE_METADATA" 2>/dev/null)
            deviceid=$(jq -r --arg ip "$device_ip" '.[$ip].deviceid // "unknown"' "$DEVICE_METADATA" 2>/dev/null)
        elif [ -f "${DEVICE_METADATA}.simple" ]; then
            local metadata_line=$(grep "^$device_ip|" "${DEVICE_METADATA}.simple" 2>/dev/null)
            if [ -n "$metadata_line" ]; then
                device_name=$(echo "$metadata_line" | cut -d'|' -f2)
                deviceid=$(echo "$metadata_line" | cut -d'|' -f3)
            fi
        fi
        
        printf "%-16s | %-22s | %s\n" "$device_ip" "$device_name" "$deviceid"
    done < "$DEVICES_FILE"
}

# Function to update prometheus configuration
update_prometheus_config() {
    if [ ! -f "$DEVICES_FILE" ]; then
        echo "No devices file found"
        return
    fi
    
    if [ ! -f "$PROMETHEUS_TEMPLATE" ]; then
        echo "Template file not found: $PROMETHEUS_TEMPLATE"
        return
    fi
    
    # Create a temporary file with device list
    local temp_devices=$(mktemp)
    while IFS= read -r device; do
        [ -z "$device" ] && continue
        echo "        - $device" >> "$temp_devices"
    done < "$DEVICES_FILE"
    
    # Generate device relabeling rules (device names and IDs)
    local temp_relabels=$(mktemp)
    if [ -f "$DEVICE_METADATA" ] && command -v jq >/dev/null 2>&1; then
        echo "      # Device metadata relabeling (auto-generated from device discovery)" >> "$temp_relabels"
        echo "      # Map IP addresses to device names and IDs" >> "$temp_relabels"
        
        # Generate relabeling rules for device names
        jq -r 'to_entries[] | "      - source_labels: [instance]\n        regex: \(.key)\n        target_label: device_name\n        replacement: \(.value.device_name // "unknown")"' "$DEVICE_METADATA" >> "$temp_relabels"
        
        echo "" >> "$temp_relabels"
        echo "      # Map IP addresses to device IDs (primary identifier)" >> "$temp_relabels"
        
        # Generate relabeling rules for device IDs  
        jq -r 'to_entries[] | "      - source_labels: [instance]\n        regex: \(.key)\n        target_label: device_id\n        replacement: \(.value.deviceid // "unknown")"' "$DEVICE_METADATA" >> "$temp_relabels"
    fi
    
    # Generate new configuration from template
    local temp_config=$(mktemp)
    while IFS= read -r line; do
        if [[ "$line" == "##IOT_DEVICES##" ]]; then
            cat "$temp_devices"
        elif [[ "$line" == "##DEVICE_RELABELS##" ]]; then
            cat "$temp_relabels"
        else
            echo "$line"
        fi
    done < "$PROMETHEUS_TEMPLATE" > "$temp_config"
    
    rm "$temp_relabels"
    
    # Replace the main config
    cp "$temp_config" "$PROMETHEUS_CONFIG"
    rm "$temp_devices" "$temp_config"
    
    # Validate the configuration
    if promtool check config "$PROMETHEUS_CONFIG" > /dev/null 2>&1; then
        echo "Prometheus configuration updated successfully"
        echo "Configuration has $(wc -l < "$DEVICES_FILE") IoT devices"
        echo "Reload Prometheus to apply changes:"
        echo "curl -X POST http://localhost:9090/-/reload"
    else
        echo "ERROR: Configuration validation failed!"
        echo "Please check the configuration manually"
        promtool check config "$PROMETHEUS_CONFIG"
        return 1
    fi
}

# Function to test device connectivity
test_device() {
    local device_ip="$1"
    if [ -z "$device_ip" ]; then
        echo "Usage: $0 test <device_ip>"
        exit 1
    fi
    
    echo "Testing device: $device_ip"
    echo "=== /info endpoint ==="
    curl -s --connect-timeout 5 "http://$device_ip/info" | jq . 2>/dev/null || echo "Failed to connect or parse /info JSON"
    
    echo "=== /config endpoint ==="
    curl -s --connect-timeout 5 "http://$device_ip/config" | jq . 2>/dev/null || echo "Failed to connect or parse /config JSON"
    
    echo "=== /hosts endpoint ==="
    curl -s --connect-timeout 5 "http://$device_ip/hosts" | jq . 2>/dev/null || echo "Failed to connect or parse /hosts JSON"
}

# Function to scan network for potential IoT devices
scan_network() {
    local network_range="$1"
    
    if [ -z "$network_range" ]; then
        echo "❌ Network range required for scanning"
        echo "   Example: 192.168.1.0/24"
        return 1
    fi
    
    echo "🔍 Scanning network range: $network_range for IoT devices..."
    
    # Use nmap to find devices with open port 80
    local temp_hosts=$(mktemp)
    
    # Scan for devices with web server (port 80)
    nmap -p 80 --open -oG - "$network_range" 2>/dev/null | 
        grep "80/open" | 
        awk '{print $2}' > "$temp_hosts"
    
    local found_devices=0
    
    # Test each potential device for IoT endpoints
    while IFS= read -r ip; do
        if [ -n "$ip" ]; then
            echo "🧪 Testing $ip for IoT endpoints..."
            if curl -s --connect-timeout 3 "http://$ip/info" | jq . >/dev/null 2>&1; then
                echo "✅ Found IoT device at $ip"
                echo "$ip" >> "$DEVICES_FILE"
                ((found_devices++))
            fi
        fi
    done < "$temp_hosts"
    
    rm -f "$temp_hosts"
    
    if [ $found_devices -eq 0 ]; then
        echo "⚠️  No IoT devices found in network range $network_range"
        return 1
    else
        echo "🎉 Found $found_devices IoT devices in network scan"
        # Try topology discovery to find network relationships
        if discover_devices; then
            echo "Topology discovery successful"
        else
            echo "Topology discovery failed, but keeping all scanned devices"
            # Since topology discovery failed, just refresh metadata for all scanned devices
            if [ -f "$DEVICES_FILE" ]; then
                while IFS= read -r device_ip; do
                    [ -z "$device_ip" ] && continue
                    echo "Refreshing metadata for $device_ip..."
                    add_device "$device_ip" >/dev/null 2>&1
                done < "$DEVICES_FILE"
                update_prometheus_config
            fi
        fi
    fi
}

# Function to discover all devices from network topology
discover_devices() {
    local discovery_ip="$1"
    
    # If no IP provided, try to find a suitable seed device from existing devices
    if [ -z "$discovery_ip" ] && [ -f "$DEVICES_FILE" ]; then
        # Try each device in the list until we find one with /hosts data
        while IFS= read -r candidate_ip; do
            [ -z "$candidate_ip" ] && continue
            echo "Testing $candidate_ip for topology discovery capability..."
            local hosts_test=$(curl -s --connect-timeout 3 "http://$candidate_ip/hosts" 2>/dev/null)
            if [ -n "$hosts_test" ] && echo "$hosts_test" | jq -e '.hosts[]?' >/dev/null 2>&1; then
                discovery_ip="$candidate_ip"
                echo "Found suitable seed device: $discovery_ip"
                break
            else
                echo "Device $candidate_ip does not provide topology data, trying next..."
            fi
        done < "$DEVICES_FILE"
    fi
    
    if [ -z "$discovery_ip" ]; then
        echo "Usage: $0 discover [device_ip]"
        echo "Please provide an IP address of any device in the network, or add at least one device first"
        echo "Note: If topology discovery fails, all scanned devices will be kept anyway"
        # Don't exit here - we might still have devices from network scan
        return 1
    fi
    
    echo "Starting comprehensive network topology discovery from $discovery_ip..."
    echo "This will crawl through all discovered devices to find the complete network..."
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required for device discovery"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required for automatic device discovery"
        echo "Install jq: apt install jq"
        exit 1
    fi
    
    # Initialize metadata file if it doesn't exist
    if [ ! -f "$DEVICE_METADATA" ]; then
        echo "{}" > "$DEVICE_METADATA"
    fi
    
    # Use associative arrays to track discovered devices
    local temp_devices=$(mktemp)
    local temp_metadata=$(mktemp)
    local discovered_ips=$(mktemp)
    local pending_ips=$(mktemp)
    
    # Copy existing metadata as base
    cp "$DEVICE_METADATA" "$temp_metadata"
    
    # Start with the initial discovery device
    echo "$discovery_ip" >> "$pending_ips"
    
    local round=1
    echo ""
    
    while [ -s "$pending_ips" ]; do
        echo "=== Discovery Round $round ==="
        local current_pending=$(mktemp)
        cp "$pending_ips" "$current_pending"
        > "$pending_ips"  # Clear pending list
        
        while IFS= read -r current_ip; do
            [ -z "$current_ip" ] && continue
            
            # Skip if already discovered
            if grep -q "^$current_ip$" "$discovered_ips" 2>/dev/null; then
                continue
            fi
            
            echo "  Querying $current_ip for network topology..."
            
            # Add to discovered list
            echo "$current_ip" >> "$discovered_ips"
            echo "$current_ip" >> "$temp_devices"
            
            # Get device metadata
            local info_data=$(curl -s --connect-timeout 5 "http://$current_ip/info" 2>/dev/null)
            local config_data=$(curl -s --connect-timeout 5 "http://$current_ip/config" 2>/dev/null)
            local hosts_data=$(curl -s --connect-timeout 5 "http://$current_ip/hosts" 2>/dev/null)
            
            local deviceid="unknown"
            local device_name="unknown"
            
                # Try to extract deviceid from /info first
                if [ -n "$info_data" ]; then
                    deviceid=$(echo "$info_data" | jq -r '.deviceid // "unknown"' 2>/dev/null)
                fi

                # Try to extract device_name from /config first
                if [ -n "$config_data" ]; then
                    device_name=$(echo "$config_data" | jq -r '.general.device_name // .network.mdns.name // .device_name // .name // .hostname // "unknown"' 2>/dev/null)
                fi

                # If still unknown, try /info for device_name
                if [ "$device_name" = "unknown" ] && [ -n "$info_data" ]; then
                    device_name=$(echo "$info_data" | jq -r '.device_name // .name // .hostname // "unknown"' 2>/dev/null)
                fi

                # If still unknown, log a warning
                if [ "$device_name" = "unknown" ]; then
                    echo "      WARNING: Could not determine device name for $current_ip"
                fi
            
            # Update metadata
            jq --arg ip "$current_ip" --arg name "$device_name" --arg id "$deviceid" --arg round "$round" \
               '.[$ip] = {device_name: $name, deviceid: $id, hostname: $name, discovered_date: now | strftime("%Y-%m-%d %H:%M:%S"), discovery_round: ($round | tonumber)}' \
               "$temp_metadata" > "${temp_metadata}.tmp" && mv "${temp_metadata}.tmp" "$temp_metadata"
            
            echo "    Device: $current_ip -> $device_name (ID: $deviceid)"
            
            # Parse hosts data and add new IPs to pending list
            if [ -n "$hosts_data" ]; then
                local hosts_found=0
                echo "$hosts_data" | jq -r '.hosts[]? | select(.visible == true) | .ip_address' 2>/dev/null | while IFS= read -r host_ip; do
                    [ -z "$host_ip" ] && continue
                    
                    # Check if this IP is new
                    if ! grep -q "^$host_ip$" "$discovered_ips" 2>/dev/null && ! grep -q "^$host_ip$" "$pending_ips" 2>/dev/null; then
                        echo "$host_ip" >> "$pending_ips"
                        hosts_found=$((hosts_found + 1))
                        echo "      -> Found new host: $host_ip"
                    fi
                done
                
                local known_hosts=$(echo "$hosts_data" | jq -r '.hosts[]? | select(.visible == true) | .ip_address' 2>/dev/null | wc -l)
                echo "    $current_ip knows about $known_hosts total hosts"
            else
                echo "    No /hosts data available from $current_ip"
            fi
            
        done < "$current_pending"
        
        rm "$current_pending"
        round=$((round + 1))
        
        if [ -s "$pending_ips" ]; then
            local pending_count=$(wc -l < "$pending_ips")
            echo "  Found $pending_count new devices to query in next round"
            echo ""
        fi
        
        # Safety limit to prevent infinite loops
        if [ $round -gt 10 ]; then
            echo "  Stopping after 10 rounds to prevent infinite loops"
            break
        fi
    done
    
    # Clean up and finalize
    rm "$pending_ips" "$discovered_ips"
    
    # Sort and deduplicate devices
    sort -u "$temp_devices" > "${temp_devices}.sorted"
    mv "${temp_devices}.sorted" "$temp_devices"
    
    # Replace files atomically
    mv "$temp_devices" "$DEVICES_FILE"
    mv "$temp_metadata" "$DEVICE_METADATA"
    
    local total_devices=$(wc -l < "$DEVICES_FILE")
    echo ""
    echo "🎉 Discovery complete! Found $total_devices total devices across $((round-1)) discovery rounds"
    echo ""
    echo "Discovered devices:"
    /etc/prometheus/manage-iot-devices.sh list
    echo ""
    echo "Updating Prometheus configuration..."
    update_prometheus_config
}

# Function to refresh metadata for existing devices
refresh_metadata() {
    if [ ! -f "$DEVICES_FILE" ]; then
        echo "No devices configured. Run discover first."
        return 1
    fi
    
    echo "Refreshing metadata for existing devices..."
    
    # Initialize metadata file if it doesn't exist
    if [ ! -f "$DEVICE_METADATA" ]; then
        echo "{}" > "$DEVICE_METADATA"
    fi
    
    local updated_count=0
    
    while IFS= read -r device_ip; do
        [ -z "$device_ip" ] && continue
        
        echo "Fetching metadata for $device_ip..."
        
        # Fetch device metadata from both config and info endpoints
    local config_data=""
    local info_data=""
    local device_name="unknown"
    local deviceid="unknown"
    local device_ip_actual="unknown"
        
        if command -v curl >/dev/null 2>&1; then
            # Get config data for device name and IP
            config_data=$(curl -s --connect-timeout 5 "http://$device_ip/config" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$config_data" ] && command -v jq >/dev/null 2>&1; then
                device_name=$(echo "$config_data" | jq -r '.general.device_name // .network.mdns.name // .device_name // .name // .hostname // "unknown"' 2>/dev/null)
                device_ip_actual=$(echo "$config_data" | jq -r '.network.connection.ip // .connection.ip // "unknown"' 2>/dev/null)
            fi

            # Get info data for device ID
            info_data=$(curl -s --connect-timeout 5 "http://$device_ip/info" 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$info_data" ] && command -v jq >/dev/null 2>&1; then
                deviceid=$(echo "$info_data" | jq -r '.deviceid // "unknown"' 2>/dev/null)
            fi
        fi
        
        # Update metadata
        if command -v jq >/dev/null 2>&1; then
            local temp_meta=$(mktemp)
            jq --arg ip "$device_ip" --arg name "$device_name" --arg id "$deviceid" --arg ip_actual "$device_ip_actual" \
               '.[$ip] = {device_name: $name, deviceid: $id, ip_address: $ip_actual, refreshed_date: now | strftime("%Y-%m-%d %H:%M:%S")}' \
               "$DEVICE_METADATA" > "$temp_meta" && mv "$temp_meta" "$DEVICE_METADATA"

            updated_count=$((updated_count + 1))
            echo "  Updated: $device_ip -> $device_name (ID: $deviceid, IP: $device_ip_actual)"
        fi
        
    done < "$DEVICES_FILE"
    
    echo "Refreshed metadata for $updated_count devices"

    # Write device_name_info metrics to persistent Prometheus textfile collector directory
    local textfile="/etc/prometheus/textfile_collector/device_name_info.prom"
    : > "$textfile"
    if command -v jq >/dev/null 2>&1; then
        jq -r 'to_entries[] | select(.value.deviceid != "unknown" and .value.device_name != "unknown") | "device_name_info{deviceid=\"" + .value.deviceid + "\",device_name=\"" + .value.device_name + "\",ip=\"" + .key + "\"} 1"' "$DEVICE_METADATA" >> "$textfile"
    fi
}

# Function for automated discovery (used by background timer)
auto_discover() {
    echo "$(date): Starting automated IoT device discovery..."
    
    # Use existing device if available, otherwise skip
    local discovery_ip=""
    if [ -f "$DEVICES_FILE" ] && [ -s "$DEVICES_FILE" ]; then
        discovery_ip=$(head -n1 "$DEVICES_FILE")
        echo "$(date): Using existing device $discovery_ip for discovery"
    else
        echo "$(date): No existing devices found, skipping auto-discovery"
        echo "$(date): Use 'manage-iot-devices.sh discover <ip>' to initialize device list"
        return 0
    fi
    
    # Count current devices
    local current_count=0
    if [ -f "$DEVICES_FILE" ]; then
        current_count=$(wc -l < "$DEVICES_FILE")
    fi
    
    echo "$(date): Current device count: $current_count"
    
    # Run discovery
    discover_devices "$discovery_ip"
    
    # Check if anything changed
    local new_count=$(wc -l < "$DEVICES_FILE")
    
    if [ "$new_count" -ne "$current_count" ]; then
        echo "$(date): Device count changed from $current_count to $new_count"
        echo "$(date): Reloading Prometheus configuration..."
        
        # In containerized environment, use Prometheus reload API instead of systemctl
        if command -v curl >/dev/null 2>&1; then
            if curl -X POST http://localhost:9090/-/reload 2>/dev/null; then
                echo "$(date): Prometheus configuration reloaded successfully"
            else
                echo "$(date): Warning: Could not reload Prometheus configuration via API"
                echo "$(date): Configuration changes will take effect on next restart"
            fi
        else
            echo "$(date): Warning: curl not available, cannot reload Prometheus"
            echo "$(date): Configuration changes will take effect on next restart"
        fi
        
        echo "$(date): Auto-discovery completed with changes"
    else
        echo "$(date): No new devices discovered, device count remains $new_count"
        # Still refresh metadata in case device names changed
        refresh_metadata
        echo "$(date): Auto-discovery completed, metadata refreshed"
    fi
}

# Main script logic
case "$1" in
    add)
        add_device "$2"
        ;;
    remove)
        remove_device "$2"
        ;;
    list)
        list_devices
        ;;
    test)
        test_device "$2"
        ;;
    update)
        update_prometheus_config
        ;;
    discover)
        discover_devices "$2"
        ;;
    refresh)
        refresh_metadata
        ;;
    auto-discover)
        auto_discover
        ;;
    scan)
        if [ -z "$2" ]; then
            echo "❌ Network range required for scan command"
            echo "   Usage: $0 scan <network_range>"
            echo "   Example: $0 scan 192.168.1.0/24"
            exit 1
        fi
        scan_network "$2"
        ;;
    *)
        echo "❌ Unknown command: $1"
        echo ""
        echo "📋 RGBWW IoT Device Management"
        echo ""
        echo "Commands:"
        echo "  add <ip>        - Add a new IoT device (queries /config for metadata)"
        echo "  remove <ip>     - Remove an IoT device"
        echo "  list            - List all configured devices with names"
        echo "  test <ip>       - Test connectivity and show all endpoints"
        echo "  update          - Update Prometheus config with current device list"
        echo "  discover [ip]   - Auto-discover all devices using /hosts endpoint"
        echo "  refresh         - Refresh metadata for existing devices"
        echo "  auto-discover   - Automated discovery for systemd timer (silent mode)"
        echo "  scan <range>    - Network scan for IoT devices (e.g., 192.168.1.0/24)"
        echo ""
        echo "Examples:"
        echo "  $0 discover 192.168.29.101    # Discover all devices via one device"
        echo "  $0 discover                   # Use first existing device for discovery"
        echo "  $0 refresh                    # Update names for existing devices"
        echo "  $0 auto-discover              # Used by systemd timer"
        ;;
esac