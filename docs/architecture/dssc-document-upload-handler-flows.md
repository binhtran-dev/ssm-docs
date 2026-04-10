# Document Upload Handler Flows

## Overview

Handles document uploads and publishes virus scan results. Operates with clean and quarantine GCS buckets.

## Key Flows

### Virus Scan Result Publishing
1. Document scanned by ClamAV
2. Handler publishes result to `virusscan.result.*` topic
3. Document service consumes result and updates document status

## GCS Buckets (per environment)
| Environment | Clean Bucket | Quarantine Bucket |
|-------------|-------------|-------------------|
| DEV | `34469-ssm-dev-us-2` | `34469-ssm-dev-us-3` |
| QA | `34469-ssm-qa-us-2` | `34469-ssm-qa-us-3` |
| UAT | `34469-ssm-uat-us-2` | `34469-ssm-uat-us-3` |
| PRD | `34469-ssm-prd-us-3` | `34469-ssm-prd-us-4` |

## Pub/Sub Topics
- **Publishes**: `virusscan.result.local`

<!-- TODO: Add sequence diagrams -->
