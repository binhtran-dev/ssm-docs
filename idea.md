I would like to create a brand new repository for docs and dev-local setup that is commons for all of the projects. Each project will include the same version of doc repo as the github sub-module

The doc repo include:

# Docs:
## architecture
- Database architecture
- [service]-flows
## contracts
- Contracts between backend services
- Contracts between UI and backend
## infrastructure
- GCP Project architecture
- Pub/sub
- Cloud function
- Mongodb
- Authentication
## patterns
- Coding standards for java 21, lombok annotation, REST convention etc.
- Database entity pattern
- Service pattern
- Testing pattern
## services
- dssc document service
- active fax cloud func
- block time service
- document upload handler
- surgical scheduler management

# Dev-local setup
## Local setup using docker compose
## Setup GCP infra locally as emulators such as spanner, cloud function, pub/sub, gcs, bigquery
- Create set of pub/sub topics, subscriptions base on a configurable file
## User will be able to do e2e testing fully locally before shipping it to GCP