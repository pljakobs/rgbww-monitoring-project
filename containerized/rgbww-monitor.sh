#!/bin/bash

# RGBWW IoT Monitoring Stack
# One-command deployment script

set -e

STACK_NAME="rgbww-monitoring"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           RGBWW IoT Monitoring Stack                ║"
    echo "║                                                      ║"
    echo "║  🔍 Automatic Device Discovery                       ║"
    echo "║  📊 Prometheus + Grafana + JSON Exporter            ║"
    echo "║  📈 Pre-configured Dashboards                       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed or not in PATH${NC}"
        echo "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        echo "Please install Docker Compose first"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        echo "Please start Docker daemon first"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker environment ready${NC}"
}

check_initial_controller() {
    if [ -z "$INITIAL_CONTROLLER_IP" ] && [ -z "$NETWORK_RANGE" ]; then
        echo -e "${YELLOW}⚠️  No initial controller or network range specified${NC}"
        echo ""
        echo -e "${BLUE}To enable automatic device discovery, you should provide:${NC}"
        echo ""
        echo -e "${YELLOW}Option 1 - Known Controller IP:${NC}"
        echo -e "  ${GREEN}export INITIAL_CONTROLLER_IP=192.168.1.100${NC}"
        echo -e "  ${GREEN}./rgbww-monitor.sh start${NC}"
        echo ""
        echo -e "${YELLOW}Option 2 - Network Range Scan:${NC}"
        echo -e "  ${GREEN}export NETWORK_RANGE=192.168.1.0/24${NC}"
        echo -e "  ${GREEN}./rgbww-monitor.sh start${NC}"
        echo ""
        echo -e "${YELLOW}Option 3 - Start anyway and add devices manually:${NC}"
        echo -e "  Access Prometheus logs to add devices manually"
        echo ""
        
        read -p "Continue without automatic discovery? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled. Set INITIAL_CONTROLLER_IP or NETWORK_RANGE and try again."
            exit 0
        fi
        echo ""
    else
        if [ -n "$INITIAL_CONTROLLER_IP" ]; then
            echo -e "${GREEN}✅ Initial controller set: $INITIAL_CONTROLLER_IP${NC}"
        fi
        if [ -n "$NETWORK_RANGE" ]; then
            echo -e "${GREEN}✅ Network range set: $NETWORK_RANGE${NC}"
        fi
    fi
}

start_stack() {
    echo -e "${BLUE}🚀 Starting RGBWW IoT Monitoring Stack...${NC}"
    echo ""
    
    # Build and start services
    docker-compose build --parallel
    echo ""
    docker-compose up -d
    
    echo ""
    echo -e "${GREEN}✅ Stack started successfully!${NC}"
}

wait_for_services() {
    echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
    
    # Wait for Prometheus
    echo -n "   Prometheus: "
    for i in {1..30}; do
        if curl -s http://localhost:9090/-/ready &> /dev/null; then
            echo -e "${GREEN}Ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for JSON Exporter
    echo -n "   JSON Exporter: "
    for i in {1..30}; do
        if curl -s http://localhost:7979/metrics &> /dev/null; then
            echo -e "${GREEN}Ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for Grafana
    echo -n "   Grafana: "
    for i in {1..30}; do
        if curl -s http://localhost:3000/api/health &> /dev/null; then
            echo -e "${GREEN}Ready${NC}"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    echo ""
}

show_access_info() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                   🎉 SUCCESS!                       ║"
    echo "║                                                      ║"
    echo "║  Your RGBWW IoT Monitoring Stack is running!        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    echo -e "${BLUE}📊 Access Your Dashboards:${NC}"
    echo ""
    echo -e "   ${YELLOW}🎯 Grafana Dashboard:${NC}"
    echo -e "      URL: ${GREEN}http://localhost:3000${NC}"
    echo -e "      User: ${GREEN}admin${NC}"
    echo -e "      Pass: ${GREEN}rgbww123${NC}"
    echo ""
    
    echo -e "   ${YELLOW}📈 Prometheus:${NC}"
    echo -e "      URL: ${GREEN}http://localhost:9090${NC}"
    echo ""
    
    echo -e "   ${YELLOW}🔧 JSON Exporter:${NC}"
    echo -e "      URL: ${GREEN}http://localhost:7979${NC}"
    echo ""
    
    echo -e "${BLUE}📋 Pre-configured Dashboards:${NC}"
    echo "   • RGBWW IoT Device Overview"
    echo "   • RGBWW Network Topology"
    echo ""
    
    echo -e "${BLUE}🔧 Management Commands:${NC}"
    echo "   • View logs: ${GREEN}docker-compose logs -f${NC}"
    echo "   • Stop stack: ${GREEN}docker-compose down${NC}"
    echo "   • Restart: ${GREEN}docker-compose restart${NC}"
    echo "   • Update: ${GREEN}docker-compose pull && docker-compose up -d${NC}"
    echo ""
    
    echo -e "${YELLOW}🔍 Device Discovery:${NC}"
    echo "   Device discovery runs automatically every 30 minutes"
    echo "   Check Prometheus logs to see discovered devices"
    echo ""
}

case "$1" in
    "start"|"")
        print_header
        check_docker
        check_initial_controller
        start_stack
        wait_for_services
        show_access_info
        ;;
    "stop")
        echo -e "${BLUE}🛑 Stopping RGBWW IoT Monitoring Stack...${NC}"
        docker-compose down
        echo -e "${GREEN}✅ Stack stopped${NC}"
        ;;
    "restart")
        echo -e "${BLUE}🔄 Restarting RGBWW IoT Monitoring Stack...${NC}"
        docker-compose restart
        echo -e "${GREEN}✅ Stack restarted${NC}"
        ;;
    "logs")
        docker-compose logs -f
        ;;
    "status")
        docker-compose ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the monitoring stack (default)"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  logs    - Show and follow logs"
        echo "  status  - Show service status"
        exit 1
        ;;
esac