# Surgical Scheduler Management (MIT Surgical) Flows

## Overview

Core case tracker application managing surgical cases, surgeon provisioning, practice management, and notifications.

## Key Flows

### Case Creation & Notification
1. Case created/updated in case tracker
2. Notifications published to `ssm.notification.local`
3. Surgery requests published to `ssm.surgeryrequest.local` (consumed by block-time-service)
4. Compliance events logged to `ssm.compliance-logging.local`

### Provisioning
1. External systems publish provisioning events
2. Service consumes: practices, surgeons, hospital units, users, rooms
3. Data synced to `casetracker` MongoDB database

## Pub/Sub Topics
- **Publishes**: `ssm.notification.local`, `ssm.surgeryrequest.local`, `edsl.notification.local`, `metrics.event.local`, `dssc.email.local`, `ssm.compliance-logging.local`
- **Subscribes**: `provision.ssm.practice.local`, `provision.ssm.surgeon.local`, `provision.ssm.hospitalunit.local`, `provision.ssm.user.local`, `provision.ssm.room.local`, `document.ssm.status.local`, `consumer.ssm.notification.local`, `consumer.ssm.authorization.local`

<!-- TODO: Add sequence diagrams -->
