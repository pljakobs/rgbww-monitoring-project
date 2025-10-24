# Use Alpine as base and install Prometheus manually for better control

FROM docker.io/library/alpine:3.18

# Install tools and dependencies
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    nmap \
    ca-certificates \
    tini

# Download and install Prometheus
RUN curl -L https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz | \
    tar xz -C /tmp && \
    mv /tmp/prometheus-2.48.0.linux-amd64/prometheus /usr/local/bin/ && \
    mv /tmp/prometheus-2.48.0.linux-amd64/promtool /usr/local/bin/ && \
    mv /tmp/prometheus-2.48.0.linux-amd64/consoles /etc/prometheus/ && \
    mv /tmp/prometheus-2.48.0.linux-amd64/console_libraries /etc/prometheus/ && \
    rm -rf /tmp/prometheus-2.48.0.linux-amd64

# Create prometheus user and directories
RUN addgroup -S prometheus && adduser -S -G prometheus prometheus && \
    mkdir -p /prometheus /etc/prometheus/data && \
    chown -R prometheus:prometheus /prometheus /etc/prometheus

# Copy configuration files
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY manage-iot-devices.sh /etc/prometheus/manage-iot-devices.sh
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable and set proper permissions
RUN chmod +x /etc/prometheus/manage-iot-devices.sh /entrypoint.sh && \
    chown -R prometheus:prometheus /etc/prometheus

# Expose port
EXPOSE 9090

# Switch to prometheus user
USER prometheus

# Use tini as init and custom entrypoint
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--web.console.libraries=/etc/prometheus/console_libraries", \
     "--web.console.templates=/etc/prometheus/consoles", \
     "--storage.tsdb.retention.time=15d", \
     "--storage.tsdb.retention.size=10GB", \
     "--web.enable-lifecycle", \
     "--web.enable-admin-api"]