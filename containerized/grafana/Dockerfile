FROM docker.io/grafana/grafana:10.2.0

# Copy setup script and dashboards
COPY setup-grafana-internal.sh /usr/local/bin/setup-grafana.sh
COPY dashboards/ /opt/dashboards/
COPY provisioning/ /etc/grafana/provisioning/

# Debug: List what was copied
RUN ls -la /opt/dashboards/ || echo "No dashboards directory found"

# Make script executable and fix permissions
USER root
RUN chmod +x /usr/local/bin/setup-grafana.sh && \
    chown -R grafana:root /opt/dashboards/ && \
    chown -R grafana:root /etc/grafana/provisioning/

# Custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER grafana

ENTRYPOINT ["/entrypoint.sh"]