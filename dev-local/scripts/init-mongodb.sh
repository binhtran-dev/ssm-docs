#!/bin/sh
# Initialize MongoDB databases.
# This is an alternative to docker-entrypoint-initdb.d for manual re-initialization.

set -e

MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"

echo "Initializing MongoDB at ${MONGO_HOST}:${MONGO_PORT}..."

mongosh --host "${MONGO_HOST}" --port "${MONGO_PORT}" /app/config/mongodb-init.js

echo "MongoDB init complete."
