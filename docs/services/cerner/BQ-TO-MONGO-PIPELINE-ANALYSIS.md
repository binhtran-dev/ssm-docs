# BigQuery-to-MongoDB Pipeline — Leverage Analysis

Analysis of the existing `dssc-ccl-bq-batch` codebase to identify reusable patterns, gaps, and recommendations for the new **BigQuery-to-MongoDB synchronization pipeline**.

---

## 1. Executive Summary

The existing `dssc-ccl-bq-batch` pipeline provides a solid foundation of patterns (multi-branch architecture, base-class DoFn, validation, metrics, DLQ, build/deploy scripts) that can be directly reused or adapted. However, the new BQ-to-MongoDB pipeline introduces significant new concerns — **MongoDB as a sink** (not Pub/Sub), **three distinct sync strategies**, **concurrency control via Firestore**, **atomic collection swap**, and **Flex Templates** (not classic templates) — that require substantial new development beyond what exists today.

**Bottom line:** ~30% structural reuse, ~70% new implementation.

---

## 2. Existing Codebase Inventory

### What `dssc-ccl-bq-batch` Does

| Component | Implementation |
|-----------|---------------|
| **Source** | BigQuery (SQL queries via `BigQueryIO.readTableRows()`) |
| **Sink** | Pub/Sub (`PubsubIO.writeMessages()`) |
| **Transform** | `DoFn<TableRow, PubsubMessage>` with typed and generic mappers |
| **Template type** | Classic Dataflow Template (JSON to GCS) |
| **Branching** | 4 independent branches (release, slots, owner, caseAction), feature-flag enabled |
| **Error handling** | Shared DLQ topic, validation via `requiredFields()` |
| **Packaging** | Fat JAR via maven-shade-plugin |
| **CI/CD** | `ascBuild()` Jenkins shared pipeline |
| **Java version** | 17 |
| **Beam version** | 2.71.0 |

### Key Source Files

| File | Purpose | Reuse Potential |
|------|---------|----------------|
| `CCLBatchPipeline.java` | Multi-branch orchestrator, early validation, DLQ merge | **High** — branch pattern is directly applicable |
| `CCLBatchPipelineOptions.java` | ValueProvider-based pipeline options | **Medium** — new options needed for MongoDB, Vault, Firestore |
| `BasePubsubMapperFn.java` | Base DoFn with metrics, validation, helpers | **High** — refactor to be sink-agnostic |
| `MapToReleasePayloadFn.java` | Typed BQ row → JSON payload | **Medium** — pattern reusable, payload model changes |
| `MapToGenericTableRowFn.java` | Pass-through BQ row → JSON | **Medium** — useful for incremental/generic branches |
| `CclJob.java` / `CclJobs.java` | Job interface + factory | **High** — extend with sync strategy metadata |
| `JobType.java` | Enum with `fromString()` | **High** — add SLOT, OWNER, RELEASE_SYNC |
| `build-template.sh` / `run-template.sh` | Template build & run scripts | **Low** — need Flex Template equivalents |
| `pom.xml` | Beam + GCP dependencies | **High** — add `beam-sdks-java-io-mongodb`, Vault, Firestore |
| `queries/*.sql` | Externalized SQL files | **High** — same pattern, different queries |

---

## 3. What Can Be Directly Reused

### 3.1 Multi-Branch Architecture (HIGH reuse)

The `CCLBatchPipeline.applyJobBranch()` pattern — feature-flagged branches with independent BQ reads, transforms, writes, and merged DLQ — maps directly to the new pipeline's three sync strategies (slot, owner, releases_synced). Each collection becomes a "branch."

**Adaptation needed:** Replace `PubsubIO.writeMessages().to(outputTopic)` with `MongoDbIO.write()` or custom MongoDB sink DoFn per branch.

### 3.2 Base DoFn Pattern (HIGH reuse)

`BasePubsubMapperFn` provides:
- Metrics (counters, distributions)
- Null-safe string helpers (`safeTrim()`, `normalizeAttributeValue()`)
- Row validation (`requiredFields()` + `validateRow()`)
- DLQ routing (`emitToDlq()` / `emitToMain()`)

**Adaptation needed:** Rename to `BaseMapperFn` or `BaseSyncFn`. Change output type from `PubsubMessage` to a generic `Document` / `org.bson.Document`. DLQ could route to a dead-letter MongoDB collection or Pub/Sub topic.

### 3.3 Job Interface + Factory (HIGH reuse)

`GenericBQPubSubJob` → rename to `SyncJob`. Add:
- `syncStrategy()` → `FULL_REPLACEMENT | INCREMENTAL_APPEND | APPLICATION_MANAGED`
- `targetCollection()` → MongoDB collection name
- `stagingCollection()` → for blue-green swap
- `windowDays()` → for incremental append (e.g., 3-day rolling window)

### 3.4 Externalized SQL Queries (HIGH reuse)

Same pattern: `.sql` files in `queries/` directory, loaded at runtime. New queries will target Dataverse curated views instead of `vw_consumer_releases`.

### 3.5 Metrics Pattern (HIGH reuse)

Counter + Distribution pattern is universally applicable. Add MongoDB-specific metrics:
- `documentsWritten`, `documentsUpserted`
- `collectionSwapLatencyMs`
- `lockAcquireLatencyMs`

### 3.6 Early Validation (HIGH reuse)

`validateBranchConfig()` pattern applies directly. Extend to validate:
- MongoDB connection URI is provided
- Target collection names are configured
- Firestore project for lock management is set

---

## 4. What Needs New Implementation

### 4.1 MongoDB Sink (NEW — Critical)

The existing pipeline writes to Pub/Sub. The new pipeline writes to MongoDB Atlas.

**Options:**

| Approach | Pros | Cons |
|----------|------|------|
| `beam-sdks-java-io-mongodb` (`MongoDbIO.write()`) | Native Beam I/O, batch-friendly, handles serialization | Limited control over upsert logic, no `renameCollection` support |
| Custom `DoFn` with MongoDB Java driver | Full control (upsert, bulk write, atomic swap) | More code, must handle connection pooling, retries |
| **Recommended: Hybrid** | Use `MongoDbIO` for simple writes, custom DoFn for upsert/swap | Balanced complexity |

**For each sync strategy:**

| Strategy | Sink Approach |
|----------|--------------|
| Full Replacement (slot) | Write to `slot_staging` via `MongoDbIO.write()`. Post-pipeline: `db.adminCommand({renameCollection: ...})` in driver program. |
| Incremental Append (owner) | Custom DoFn with `ReplaceOptions.upsert(true)` on MongoDB driver. Filter: 3-day rolling window via BQ partition time. |
| Application-Managed (releases_synced) | Full replacement same as slot. Aggregation pipeline (`$lookup` + `$merge`) triggered post-load. |

### 4.2 Concurrency Control — Firestore Locking (NEW — Critical)

Not present in `dssc-ccl-bq-batch`. Required to prevent overlapping hourly jobs from corrupting data.

**Implementation:**

```
_pipeline_locks/{collectionName}
├── holder: "job-{uuid}"
├── acquiredAt: timestamp
├── ttl: 60 minutes
└── status: "ACTIVE" | "EXPIRED"
```

- Acquire lock before pipeline execution (fail-fast if locked)
- Release lock in `finally` block
- TTL-based expiry for crash recovery
- Use Firestore transactions for atomic acquire

**Placement:** In the driver program (`main()` method), wrapping the `pipeline.run().waitUntilFinish()` call.

### 4.3 Atomic Collection Swap (NEW — Critical for Full Replacement)

Post-pipeline step for the `slot` and `releases_synced` branches:

```java
// After pipeline writes to staging collection:
MongoDatabase db = mongoClient.getDatabase("ssm");
db.getCollection("slot_staging").renameCollection(
    new MongoNamespace("ssm", "slot"),
    new RenameCollectionOptions().dropTarget(true));
```

**Must happen:** After `pipeline.run().waitUntilFinish()` returns `DONE`, before lock release.

### 4.4 Flex Templates (NEW — replaces Classic Templates)

The existing pipeline uses **classic templates** (JSON staged to GCS). The new pipeline should use **Flex Templates** (Docker image in Artifact Registry), which:
- Allow arbitrary initialization code (Firestore lock, Vault credential fetch)
- Support custom container images with additional dependencies
- Are the recommended approach for new pipelines

**New artifacts needed:**
- `Dockerfile` for Flex Template
- `metadata.json` (template parameter schema)
- Build script: `gcloud dataflow flex-template build`
- Run script: `gcloud dataflow flex-template run`

### 4.5 Credential Management — HashiCorp Vault (NEW)

`dssc-ccl-bq-batch` needs only GCP-native credentials (BigQuery → Pub/Sub, same project). The new pipeline needs MongoDB Atlas credentials from Vault.

**Implementation:**
- Use GCP Auth Method to authenticate to Vault
- Fetch dynamic MongoDB credentials at pipeline startup (driver program)
- Pass credentials as pipeline options or `Setup`/`Teardown` in DoFn
- **Do NOT bake credentials into the template or environment variables**

### 4.6 Pre-flight & Post-flight Validation (NEW)

Not present in existing pipeline. Required for data quality assurance.

| Phase | Check |
|-------|-------|
| Pre-flight | Validate source BQ view exists and returns rows > 0 (guard against empty-source full-replacement) |
| Post-flight | Compare BQ source count vs MongoDB target count. Log structured JSON reconciliation report. |

### 4.7 VPC Peering Configuration (NEW)

Existing pipeline uses `--network` and `--subnetwork` for Dataflow workers to reach Pub/Sub (within GCP). The new pipeline additionally needs VPC Peering to MongoDB Atlas (private endpoint, no public internet).

- Dataflow workers must be in a subnet with VPC Peering to Atlas
- Security group / firewall rules for port 27017
- DNS resolution for Atlas private endpoints

---

## 5. Recommended Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Driver Program                         │
│  1. Fetch credentials from Vault                         │
│  2. Acquire Firestore lock per collection                │
│  3. Pre-flight: validate BQ source views                 │
│  4. Build & run Beam pipeline                            │
│  5. Post-flight: reconciliation counts                   │
│  6. Atomic swap (full replacement branches)              │
│  7. Trigger aggregation (releases unified view)          │
│  8. Release Firestore lock                               │
└──────────────────┬───────────────────────────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    ▼              ▼                  ▼
┌────────┐   ┌─────────┐   ┌──────────────┐
│  slot  │   │  owner  │   │releases_synced│
│(branch)│   │(branch) │   │  (branch)     │
└───┬────┘   └───┬─────┘   └──────┬───────┘
    │            │                 │
    ▼            ▼                 ▼
 BQ Read      BQ Read           BQ Read
    │            │                 │
    ▼            ▼                 ▼
 Transform   Transform         Transform
    │            │                 │
    ▼            ▼                 ▼
 MongoWrite  MongoUpsert       MongoWrite
 (staging)   (3-day window)    (staging)
    │                              │
    ▼                              ▼
 renameCol                     renameCol
                                   │
                                   ▼
                            $lookup + $merge
                            (unified view)
```

---

## 6. Dependency Changes (pom.xml)

**Keep from existing:**
- `beam-sdks-java-core` (2.71.0 — or pin to 2.55.1+ for MongoDB IO stability)
- `beam-sdks-java-io-google-cloud-platform` (BigQuery IO)
- `beam-runners-google-cloud-dataflow-java`
- `beam-runners-direct-java` (local testing)
- `gson`
- `slf4j-api` + `slf4j-simple`
- `maven-shade-plugin`

**Add new:**
```xml
<!-- MongoDB Beam IO -->
<dependency>
  <groupId>org.apache.beam</groupId>
  <artifactId>beam-sdks-java-io-mongodb</artifactId>
  <version>${beam.version}</version>
</dependency>

<!-- MongoDB Java Driver (for atomic swap, aggregation, connection management) -->
<dependency>
  <groupId>org.mongodb</groupId>
  <artifactId>mongodb-driver-sync</artifactId>
  <version>4.11.1</version>
</dependency>

<!-- Firestore (for distributed locking) -->
<dependency>
  <groupId>com.google.cloud</groupId>
  <artifactId>google-cloud-firestore</artifactId>
</dependency>

<!-- Vault (for credential management) -->
<dependency>
  <groupId>io.github.jopenlibs</groupId>
  <artifactId>vault-java-driver</artifactId>
  <version>5.4.0</version>
</dependency>

<!-- JUnit 5 + TestPipeline + Testcontainers -->
<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <version>5.10.2</version>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.testcontainers</groupId>
  <artifactId>mongodb</artifactId>
  <version>1.19.7</version>
  <scope>test</scope>
</dependency>
```

---

## 7. What to Improve Over the Existing Pipeline

| Area | Current (`dssc-ccl-bq-batch`) | Recommended (new pipeline) |
|------|-------------------------------|---------------------------|
| **Testing** | No tests (JUnit 4 dependency unused) | JUnit 5 + `TestPipeline` for transforms, Testcontainers for MongoDB integration tests |
| **Template type** | Classic (limited: no pre/post steps) | **Flex Template** (Docker-based, supports driver program logic) |
| **Error handling** | DLQ to Pub/Sub topic only | DLQ to Pub/Sub + structured error logging + dead-letter MongoDB collection |
| **Credential management** | GCP-native only | HashiCorp Vault with GCP Auth Method |
| **Concurrency** | None (no overlap protection) | Firestore lease-based locking |
| **Data quality** | None | Pre-flight source validation + post-flight reconciliation |
| **Monitoring** | Beam metrics only | Beam metrics + Cloud Monitoring custom dashboards + alerting |
| **Query duplication** | All 4 queries are identical (placeholder) | Each query targets its specific Dataverse view |
| **IaC** | Manual GCP resource setup | **Terraform** for topics, subscriptions, Dataflow schedules, IAM, VPC peering |
| **Packaging** | Fat JAR only | Fat JAR + Docker image (Flex Template) |
| **Java** | 17 | 17 (or 21 if Beam supports it by then) |

---

## 8. Implementation Phases

### Phase 1: Foundation & Slot (Full Replacement)
1. Fork/copy `dssc-ccl-bq-batch` as `dssc-bq-mongo-sync` (new repo)
2. Refactor base classes to be sink-agnostic (`BaseSyncFn<OutputT>`)
3. Add MongoDB dependencies + Vault + Firestore
4. Implement `slot` branch: BQ read → transform → write to staging → atomic swap
5. Implement Firestore locking in driver program
6. Implement Vault credential fetch
7. Build Flex Template (Dockerfile + metadata.json)
8. Write unit tests (TestPipeline) + integration tests (Testcontainers)
9. Deploy to QA with Terraform

### Phase 2: Owner (Incremental Append)
1. Implement `owner` branch with upsert DoFn and 3-day rolling window
2. Add pre-flight validation (source view row count > 0)
3. Add post-flight reconciliation logging

### Phase 3: Releases (Application-Managed + Unified View)
1. Implement `releases_synced` branch (full replacement, same as slot)
2. Implement post-load aggregation pipeline (`$lookup` + `$merge` for `releases_unified_view`)
3. Coordinate with application team on `release_workflows` collection ownership

### Phase 4: Production Readiness
1. Cloud Monitoring dashboards + alerting (PagerDuty/Slack)
2. Terraform for all environments (dev, qa, uat, prod)
3. Jenkinsfile for CI/CD (build → test → Flex Template → deploy)
4. Runbooks and operational documentation

---

## 9. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MongoDB Atlas VPC Peering delays | Medium | High | Start peering request early; can test with public endpoint + IP allowlist in QA |
| Vault integration complexity | Medium | Medium | Prototype credential fetch in isolation first; fallback to Secret Manager |
| Beam MongoDB IO limitations for upsert | Low | Medium | Use custom DoFn with MongoDB driver directly for upsert branches |
| Atomic swap fails mid-operation | Low | High | `renameCollection` is atomic in MongoDB; staging collection preserved on failure |
| Overlapping job execution | Medium | High | Firestore locking with TTL; Cloud Scheduler backoff configuration |
| BQ source view returns 0 rows | Low | Critical | Pre-flight validation halts pipeline; alerting on empty source |

---

## 10. Summary of Reuse Decisions

| Component | Decision |
|-----------|----------|
| Multi-branch pattern | ✅ **Reuse** — adapt sink from Pub/Sub to MongoDB |
| Base DoFn class | ✅ **Reuse** — generalize output type |
| Job interface + factory | ✅ **Reuse** — extend with sync strategy metadata |
| SQL query externalization | ✅ **Reuse** — same pattern, new queries |
| Metrics framework | ✅ **Reuse** — add MongoDB-specific counters |
| Early validation | ✅ **Reuse** — extend for MongoDB/Vault/Firestore config |
| ValueProvider options | ✅ **Reuse** — add new MongoDB/Vault/lock options |
| Build scripts | 🔄 **Replace** — Flex Template build replaces classic template build |
| pom.xml | 🔄 **Extend** — add MongoDB, Vault, Firestore, JUnit 5, Testcontainers |
| Pub/Sub sink | ❌ **Drop** — replaced by MongoDB sink |
| Classic template | ❌ **Drop** — replaced by Flex Template |
| Pub/Sub message attributes | ❌ **Drop** — not applicable for MongoDB documents |
