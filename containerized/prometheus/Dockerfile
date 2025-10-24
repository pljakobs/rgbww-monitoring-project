FROM docker.io/prom/prometheus:v2.48.0

# Install additional tools for device discovery
USER root
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    nmap \
    && rm -rf /var/cache/apk/*

# Copy configuration files
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY manage-iot-devices.sh /etc/prometheus/manage-iot-devices.sh
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /etc/prometheus/manage-iot-devices.sh /entrypoint.sh

# Create directories for device management
RUN mkdir -p /etc/prometheus/data

# Switch back to prometheus user
USER prometheus

# Use custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--web.console.libraries=/etc/prometheus/console_libraries", \
     "--web.console.templates=/etc/prometheus/consoles", \
     "--storage.tsdb.retention.time=15d", \
     "--storage.tsdb.retention.size=10GB", \
     "--web.enable-lifecycle", \
     "--web.enable-admin-api"]