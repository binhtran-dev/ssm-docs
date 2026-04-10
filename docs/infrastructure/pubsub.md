# Pub/Sub Infrastructure

## Overview

Google Cloud Pub/Sub is used for asynchronous inter-service communication across the SSM platform.

## Topic Registry

See [dev-local/config/pubsub-manifest.yaml](../../dev-local/config/pubsub-manifest.yaml) for the canonical list of all topics and subscriptions.

## Naming Conventions

- **Topics**: `<domain>.<entity>.<environment>` (e.g., `document.scan.local`)
- **Subscriptions**: `<consumer>.<domain>.<entity>.<environment>` (e.g., `consumer.blocktime.case.local`)
- **Cron subscriptions**: `cron.<service>.<purpose>.<environment>` (e.g., `cron.bts.release-reco.local`)
- **Provisioning**: `provision.ssm.<entity>.<environment>` (e.g., `provision.ssm.surgeon.local`)

## Dead Letter Topics

<!-- TODO: Document DLQ strategy -->
