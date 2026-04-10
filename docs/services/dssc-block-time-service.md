# dssc-block-time-service

## Overview

Spring Boot application managing block time definitions, release schedules, open time, and nudge notifications.

## Tech Stack

- Java 21, Spring Boot
- MongoDB (`dssc-block-time-service` database)
- GCP Pub/Sub
- Deployed to GKE via Helm

## Repository

`git@github.ascension.org:Ascension/dssc-block-time-service.git`

## Key Endpoints

<!-- TODO: List REST API endpoints (see api-test/open_api.yaml) -->

## Configuration

- Profiles: `cloud`, `local`
- Pub/Sub topics: See [architecture flows](../architecture/dssc-block-time-service-flows.md)

## Local Development

```bash
cd .shared-docs/dev-local && ./scripts/start.sh
# Run service with: -Dspring.profiles.active=local
```
