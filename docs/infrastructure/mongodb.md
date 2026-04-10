# MongoDB

## Overview

All SSM services use MongoDB Atlas in cloud environments and a local Docker MongoDB for development.

## Databases

| Database | Service | Description |
|----------|---------|-------------|
| `document-service` | dssc-document-service | Document metadata, scan results |
| `dssc-block-time-service` | dssc-block-time-service | Block time, releases, schedules |
| `casetracker` | mit-surgical | Cases, surgeons, practices, rooms |

## Connection

- **Cloud**: MongoDB Atlas with SSL, replica set
- **Local**: `mongodb://localhost:27017/<database>`

## Indexes & Migration Strategy

<!-- TODO: Document index strategy and data migration approach -->
