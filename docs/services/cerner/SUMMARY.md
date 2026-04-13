# SSM Cerner Data Integration — Summary

This document summarizes three Confluence pages covering the migration of SSM's data ingestion from legacy Cerner CCL extracts to a modern BigQuery-based architecture, and the synchronization pipeline that hydrates MongoDB from BigQuery.

---

## 1. Architecture & Data Flow (As-Is vs. To-Be)

### As-Is (Current State)

A traditional, multi-step, file-based ETL process:

1. **Cerner** — Source of truth for surgical scheduling data.
2. **Scheduled Extraction** — Daily at 2 AM, CCL scripts (`SSM_MANUAL_SLOTS_EXT`, `SSM_SLOTS_EXT`, etc.) run against the Cerner database.
3. **CSV File Drop** — Output as CSV files to an FTP server.
4. **Health Connect Cron Job** — Pulls CSVs from FTP.
5. **SSM Application** — Parses CSVs and loads data into its local database.

**Characteristics:** Point-to-point, brittle (multiple failure points), high latency (24+ hours).

### To-Be (Proposed Future State)

Leverages the enterprise GCP data platform (Dataplace & Dataverse):

1. **Cerner** — Source of truth (unchanged).
2. **Dataplace Ingestion** — Central team ingests raw Cerner data directly into BigQuery (replaces CCL scripts, FTP, Health Connect).
3. **BigQuery (Raw Layer)** — Raw Cerner tables land in `cerner_tnnas_ingest`.
4. **Dataform (Transformation)** — CCL logic is converted to Dataform SQL scripts by the EaaS team.
5. **BigQuery (Curated Dataverse Layer)** — Clean, governed, reusable views.
6. **SSM Application** — Connects directly to BigQuery via GCP service account and client library.

**Characteristics:** Decoupled, governed, reusable, low latency (minutes/hours vs. 24+ hours).

---

## 2. SSM Cerner CCL Migration to BigQuery

### Overview

Migrates SSM's data ingestion from legacy Cerner CCL extracts (CSV via HealthConnect/SBF) to Google BigQuery. Decouples SSM from the legacy extract process, leveraging Dataplace for ingestion and Dataverse views for consumption.

### Key Teams

| Team | Primary Contacts | Responsibilities |
|------|-----------------|------------------|
| SSM (Application) | Edgardo Cruz Sastre, Dioleisys Fontela Gonzalez | App development, consuming BigQuery data, UAT, Go-Live |
| Clinical Data Extracts | Alan Snow, Andy Peake | Conversion of CCL scripts to BigQuery SQL/Dataform |
| Dataplace/Dataverse | Kary Kummins, Dustin Cole | Deployment of curated views in DataLens/Dataverse |
| Project Management | Cassandra Lill | Oversight, funding, cross-team coordination |
| Stakeholders | David Martin, Brent Baron | Business and project sponsorship |

### Key Deliverables

- Architecture & data flow documentation
- Data source analysis & mapping (CCL → BigQuery)
- Implementation plan & work breakdown
- Decision log & open questions
- Meeting notes & status updates

---

## 3. BigQuery to MongoDB Synchronization Pipeline

### Purpose

Hourly data sync from BigQuery to MongoDB Atlas, hydrating the transactional database with data mastered in the analytical warehouse. Provides low-latency access to fresh data without querying BigQuery for operational workloads.

### Architecture

Built entirely on **Google Cloud Dataflow** with native scheduling (hourly). All orchestration logic (concurrency control, post-load operations) is managed within the Dataflow driver program.

### Three Synchronization Patterns

| Collection | Strategy | Description |
|-----------|----------|-------------|
| `slot` | **Full Replacement** (blue-green) | Exact mirror of source. Builds a staging collection, then atomically swaps via `renameCollection`. Handles deletions natively, zero downtime. |
| `owner` | **Incremental Append** | Immutable time-series data. Re-processes a rolling 3-day window using BigQuery partition time. Uses upsert to ensure idempotency. |
| `releases_synced` + `release_workflows` | **Application-Managed & Unified View** | Pipeline syncs `releases_synced` (full replacement). App manages `release_workflows`. A MongoDB aggregation (`$lookup` + `$merge`) produces `releases_unified_view` for consumers. |

### Concurrency Control

- **Problem:** If a job exceeds 60 minutes, the scheduler triggers a new instance, risking data corruption.
- **Solution:** Lease-based locking via Firestore (`_pipeline_locks/{collectionName}`). Lock acquired before execution, released in `finally` block.

### Security & Networking

| Concern | Solution |
|---------|----------|
| Network isolation | VPC Peering between GCP VPC and MongoDB Atlas VPC — no public internet traffic |
| Credentials | HashiCorp Vault with GCP Auth Method and dynamic secrets |
| IAM | Dedicated service account with least-privilege roles (`dataflow.admin`, `bigquery.dataViewer`, `bigquery.jobUser`, etc.) |

### Implementation

- **Language:** Java (Apache Beam SDK)
- **Packaging:** Dataflow Flex Templates (Docker images in Artifact Registry)
- **Dependencies:** `beam-runners-google-cloud-dataflow-java`, `beam-sdks-java-io-google-cloud-platform`, `beam-sdks-java-io-mongodb` (v2.55.1)
- **Driver Program:** Orchestrates lock acquisition, pre-flight checks, pipeline execution, atomic swap, and lock release.

### Monitoring & Alerting

| Alert | Condition | Channel |
|-------|-----------|---------|
| Dataflow Job Failed | `job/is_failed > 0` | PagerDuty / Slack |
| Anomalous Job Duration | `job/elapsed_time > 45 min` | Slack |

Custom Cloud Monitoring dashboards track: job status, elapsed time, element counts, worker CPU/memory.

### Data Quality

- **Pre-flight:** Validates source BigQuery view before running pipeline.
- **Post-flight:** Logs structured JSON reconciliation report comparing source row count vs. records written.

### CI/CD & Testing

- **Testing:** Unit tests (JUnit 5 + `TestPipeline`), integration tests (Testcontainers).
- **CI/CD:** Jenkinsfile → Build & Test → Build Flex Template (fat JAR + Docker) → Deploy scheduled Dataflow job.
- **IaC:** All GCP resources managed via Terraform.

### Dataflow vs. Cloud Run Decision

Dataflow was chosen over Cloud Run for:
- **Scalability:** Massively parallel processing, auto-scaling worker nodes.
- **Use case fit:** Purpose-built for large-scale data movement between BigQuery and external databases.
- **Future-proofing:** Handles complex joins, enrichments, windowing within the same framework.
- **Trade-off:** Higher initial complexity and cost accepted as strategic investment.
