FROM docker.io/library/alpine:3.18

# Install JSON Exporter
RUN apk add --no-cache ca-certificates curl && \
    curl -L https://github.com/prometheus-community/json_exporter/releases/download/v0.6.0/json_exporter-0.6.0.linux-amd64.tar.gz | \
    tar xz -C /tmp && \
    mv /tmp/json_exporter-0.6.0.linux-amd64/json_exporter /usr/local/bin/ && \
    rm -rf /tmp/json_exporter-0.6.0.linux-amd64 && \
    apk del curl

# Copy configuration
COPY json_exporter.yml /etc/json_exporter.yml

# Create user
RUN addgroup -S json_exporter && adduser -S -G json_exporter json_exporter

# Set ownership
RUN chown json_exporter:json_exporter /etc/json_exporter.yml

USER json_exporter

EXPOSE 7979

ENTRYPOINT ["/usr/local/bin/json_exporter"]
CMD ["--config.file=/etc/json_exporter.yml", "--web.listen-address=:7979"]