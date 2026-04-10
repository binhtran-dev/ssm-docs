# dssc-document-service

## Overview

Spring Boot application managing document lifecycle — upload, virus scanning, storage, and status notifications.

## Tech Stack

- Java 21, Spring Boot
- MongoDB (`document-service` database)
- GCP Pub/Sub, GCS
- Deployed to GKE via Helm

## Repository

`git@github.ascension.org:Ascension/dssc-document-service.git`

## Key Endpoints

<!-- TODO: List REST API endpoints -->

## Configuration

- Profiles: `cloud`, `local`
- Pub/Sub topics: See [architecture flows](../architecture/dssc-document-service-flows.md)

## Local Development

```bash
cd .shared-docs/dev-local && ./scripts/start.sh
# Run service with: -Dspring.profiles.active=local
```
