# dssc-document-upload-handler

## Overview

Cloud Function handling document uploads and publishing virus scan results to Pub/Sub.

## Tech Stack

- Java, Cloud Functions Framework
- GCS (clean + quarantine buckets)
- GCP Pub/Sub

## Repository

`git@github.ascension.org:Ascension/dssc-document-upload-handler.git`

## GCS Buckets

| Environment | Clean | Quarantine |
|-------------|-------|------------|
| DEV | `34469-ssm-dev-us-2` | `34469-ssm-dev-us-3` |
| QA | `34469-ssm-qa-us-2` | `34469-ssm-qa-us-3` |
| UAT | `34469-ssm-uat-us-2` | `34469-ssm-uat-us-3` |
| PRD | `34469-ssm-prd-us-3` | `34469-ssm-prd-us-4` |

## Deployment

Per-environment deploy scripts: `deploy-dev.sh`, `deploy-qa.sh`, `deploy-uat.sh`, `deploy-prd.sh`
