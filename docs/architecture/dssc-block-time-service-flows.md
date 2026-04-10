# Block Time Service Flows

## Overview

Manages surgical block time definitions, release schedules, open time notifications, and nudge emails.

## Key Flows

### Release Nudge Flow
1. Cron triggers release evaluation
2. Service evaluates block utilization
3. If underutilized, publishes to `adsi.historical.local`
4. Nudge email sent via `dssc.email.local`

### Open Time Subscription
1. Receives open time events via `cron.blocktime.opentimesubscriber.local`
2. Updates block time availability

## Pub/Sub Topics
- **Publishes**: `adsi.historical.local`, `dssc.email.local`, `metrics.event.local`
- **Subscribes**: `adsi.ssm.releasenudge.local`, `cron.blocktime.opentimesubscriber.local`, `clinx.blocktime.opentimesubscription.local`, `consumer.blocktime.release.local`, `cron.bts.release-reco.local`, `consumer.blocktime.slot.local`, `consumer.blocktime.case.local`, `consumer.blocktime.notification.local`, `cron.bts.nudge-email.local`, `ssm.blocktime.surgeryrequest.local`

<!-- TODO: Add sequence diagrams -->
