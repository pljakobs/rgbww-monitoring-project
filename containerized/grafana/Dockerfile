FROM docker.io/grafana/grafana:10.2.0

# Copy setup script and dashboards
COPY setup-grafana-internal.sh /usr/local/bin/setup-grafana.sh
COPY dashboards/ /var/lib/grafana/dashboards/
COPY provisioning/ /etc/grafana/provisioning/

# Make script executable and fix permissions
USER root
RUN chmod +x /usr/local/bin/setup-grafana.sh && \
    chown -R grafana:root /var/lib/grafana/dashboards/ && \
    chown -R grafana:root /etc/grafana/provisioning/

# Custom entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER grafana

ENTRYPOINT ["/entrypoint.sh"]