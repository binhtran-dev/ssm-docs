# dssc-active-fax-cloud-func

## Overview

Google Cloud Function (Gen2) triggered by Cloud Storage events to process RightFax files.

## Tech Stack

- Java, Cloud Functions Framework
- GCS (event trigger + destination bucket)
- No database

## Repository

`git@github.ascension.org:Ascension/dssc-active-fax-cloud-func.git`

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DESTINATION_BUCKET` | Target GCS bucket for processed files |
| `DESTINATION_PATH` | Target path within the bucket |

## Deployment

Per-environment deploy scripts: `deploy-dev.sh`, `deploy-qa.sh`, `deploy-uat.sh`, `deploy-prod.sh`
