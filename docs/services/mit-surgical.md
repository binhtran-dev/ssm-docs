# mit-surgical (Surgical Scheduler Management)

## Overview

Core case tracker application managing surgical cases, surgeon provisioning, practice management, notifications, and compliance logging.

## Tech Stack

- Java 21, Spring Boot
- MongoDB (`casetracker` database)
- GCP Pub/Sub
- Deployed to GKE via Helm

## Repository

`git@github.ascension.org:Ascension/mit-surgical.git`

## Key Endpoints

<!-- TODO: List REST API endpoints -->

## Configuration

- Profiles: `cloud`, `local`
- Environments: dev, qa, uat, prod, sbx1, sbx2
- Pub/Sub topics: See [architecture flows](../architecture/mit-surgical-flows.md)

## Local Development

```bash
cd .shared-docs/dev-local && ./scripts/start.sh
# Run service with: -Dspring.profiles.active=local
```
