# Document Service Flows

## Overview

Manages document lifecycle: upload → virus scan → store/quarantine → status notification.

## Key Flows

### Document Upload & Scan
1. Document uploaded to GCS unprocessed bucket (`34469-ssm-*-us-1`)
2. Service publishes scan request to `document.scan.local`
3. ClamAV scans the document
4. Upload handler publishes result to `virusscan.result.*`
5. Document service receives result, moves to clean (`us-2`) or quarantine (`us-3`) bucket
6. Status published to `document.status.local`

### Pub/Sub Topics
- **Publishes**: `document.scan.local`, `document.status.local`, `ssm.compliance-logging.local`
- **Subscribes**: `virusscan.document.result.local`, `document.document.scan.local`

<!-- TODO: Add sequence diagrams -->
