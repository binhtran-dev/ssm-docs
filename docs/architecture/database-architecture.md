# Database Architecture

## Overview

All SSM services use MongoDB (Atlas in cloud, local Docker for development).

## Databases

| Database | Service | Description |
|----------|---------|-------------|
| `document-service` | dssc-document-service | Document metadata, scan status |
| `dssc-block-time-service` | dssc-block-time-service | Block time definitions, release schedules |
| `casetracker` | mit-surgical | Cases, surgeons, practices, rooms, hospital units |

## Cross-Service Data Flow

<!-- TODO: Add entity relationship diagrams and cross-service data dependencies -->
