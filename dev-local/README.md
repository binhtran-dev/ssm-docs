# Dev-Local Setup

Local development environment using Docker Compose with GCP emulators for full E2E testing.

## Prerequisites

- Docker & Docker Compose v2+
- `gcloud` CLI (for Pub/Sub init script)

## Quick Start

```bash
cp .env.example .env
./scripts/start.sh
```

## Services

| Service | Port | Purpose |
|---------|------|---------|
| MongoDB | 27017 | Database (document-service, block-time-service, casetracker) |
| Pub/Sub Emulator | 8085 | Google Cloud Pub/Sub emulator |
| Fake GCS Server | 4443 | Google Cloud Storage emulator |
| BigQuery Emulator | 9050 (gRPC), 9060 (HTTP) | BigQuery emulator |
| Functions Framework | 8080 | Cloud Functions local runtime |

## Configuration

### Pub/Sub Topics & Subscriptions

All topics and subscriptions are defined in [`config/pubsub-manifest.yaml`](config/pubsub-manifest.yaml).
The init script reads this manifest and creates them on the emulator.

### GCS Buckets

Buckets are defined in [`config/gcs-buckets.yaml`](config/gcs-buckets.yaml).

### MongoDB

Databases and seed data are initialized via [`config/mongodb-init.js`](config/mongodb-init.js).

## Connecting Your Service

Set these environment variables (or Spring profile `local`):

```bash
# Pub/Sub
export PUBSUB_EMULATOR_HOST=localhost:8085

# GCS
export STORAGE_EMULATOR_HOST=http://localhost:4443

# BigQuery
export BIGQUERY_EMULATOR_HOST=http://localhost:9060

# MongoDB
export SPRING_DATA_MONGODB_URI=mongodb://localhost:27017/your-database
```

## Stopping

```bash
docker compose down
# To remove all data:
docker compose down -v
```
