# Active Fax Cloud Function Flows

## Overview

Google Cloud Function (Gen2) triggered by Cloud Storage events. Processes RightFax files by parsing directory structure to extract metadata (ministry, fax numbers) and moves files to a destination bucket.

## Key Flows

### Fax File Processing
1. RightFax deposits file into source GCS bucket
2. Cloud Storage event triggers the cloud function
3. Function parses directory path for metadata (ministry, sender/receiver fax)
4. File moved to destination bucket with extracted metadata

## Configuration
- **Source**: RightFax GCS bucket (event trigger)
- **Destination**: Configured via `DESTINATION_BUCKET` and `DESTINATION_PATH` env vars
- **Trigger**: Cloud Storage OBJECT_FINALIZE event (not Pub/Sub)

<!-- TODO: Add detailed flow diagrams -->
