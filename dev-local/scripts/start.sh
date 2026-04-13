#!/bin/bash
# Start the full local development environment.
# Usage: ./scripts/start.sh [--clean]
#
# Options:
#   --clean   Remove all volumes and start fresh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEV_LOCAL_DIR="$(dirname "$SCRIPT_DIR")"

cd "$DEV_LOCAL_DIR"

# Load .env if it exists
if [ ! -f .env ]; then
    echo "No .env file found. Copying from .env.example..."
    cp .env.example .env
fi

# Handle --clean flag
if [ "$1" = "--clean" ]; then
    echo "Cleaning up volumes..."
    docker-compose down -v
fi

echo "Starting SSM local development environment..."
echo "================================================"

# Start all services
docker-compose up -d

echo ""
echo "Waiting for services to be healthy..."
docker-compose ps

echo ""
echo "================================================"
echo "SSM Local Environment Ready!"
echo "================================================"
echo ""
echo "Services:"
echo "  MongoDB:          mongodb://localhost:27017"
echo "  Pub/Sub Emulator: localhost:8085"
echo "  GCS (fake):       http://localhost:4443"
echo "  BigQuery:         http://localhost:9060 (HTTP), localhost:9050 (gRPC)"
echo ""
echo "Environment variables for your service:"
echo "  export PUBSUB_EMULATOR_HOST=localhost:8085"
echo "  export STORAGE_EMULATOR_HOST=http://localhost:4443"
echo "  export BIGQUERY_EMULATOR_HOST=http://localhost:9060"
echo "  export SPRING_DATA_MONGODB_URI=mongodb://localhost:27017/<your-database>"
echo ""
echo "To stop: docker-compose down"
echo "To stop and clean: docker-compose down -v"
