# Cloud Functions

## Deployed Functions

### dssc-active-fax-cloud-func
- **Runtime**: Java (Cloud Function Gen2)
- **Trigger**: Cloud Storage OBJECT_FINALIZE event
- **Purpose**: Process RightFax files, extract metadata, move to destination bucket

### dssc-document-upload-handler
- **Runtime**: Java (Cloud Function)
- **Trigger**: Pub/Sub / direct invocation
- **Purpose**: Handle document uploads and publish virus scan results

## Deployment

Each function has per-environment deploy scripts:
```bash
deploy-dev.sh
deploy-qa.sh
deploy-uat.sh
deploy-prod.sh
```

<!-- TODO: Add function configurations and environment variables -->
