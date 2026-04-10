# GCP Project Architecture

## Project

- **Project ID**: `asc-ahnat-casetracker-dev` (dev environment)
- **Region**: US

## Services Deployed

| Service | Runtime | Deployment |
|---------|---------|-----------|
| dssc-document-service | Java 21 / Spring Boot | GKE (Helm) |
| dssc-block-time-service | Java 21 / Spring Boot | GKE (Helm) |
| mit-surgical | Java 21 / Spring Boot | GKE (Helm) |
| dssc-active-fax-cloud-func | Java / Cloud Function Gen2 | Cloud Functions |
| dssc-document-upload-handler | Java / Cloud Function | Cloud Functions |
| dssc-clamav-run | Cloud Run | Cloud Run |

## Environment Matrix

| Environment | Suffix | GKE Helm Values |
|------------|--------|-----------------|
| Development | `-dev` | `values-dev.yaml` |
| QA | `-qa` | `values-qa.yaml` |
| UAT | `-uat` | `values-uat.yaml` |
| Production | `-prod` | `values-prod.yaml` |

<!-- TODO: Add GCP architecture diagram -->
