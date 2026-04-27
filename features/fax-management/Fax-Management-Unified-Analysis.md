# Fax Management - Unified Product, Technical, and Architecture Analysis

## 1. Feature Overview

### High-level description
Fax Management is a TXAUS-focused workflow that brings inbound RightFax documents into SSM so OR Schedulers can process fax documents, index metadata, link to surgical cases, and track document lifecycle and activity without using a parallel fax system.

### End-to-end user flows
1. Inbound fax intake and queue assignment
   - RightFax drops PDF into GCS path by ministry and fax numbers.
   - Cloud Function parses metadata (ministry, sender/receiver fax) and moves file with metadata.
   - Document service creates the document and places it in scheduler queue context.
2. Queue triage and filtering
   - Scheduler opens Fax Management list, sees task cards and counts by queue.
   - Scheduler applies filters (status, queue, dates, FIN, patient, procedure) and identifies next documents.
3. Open document and review
   - Scheduler opens PDF viewer screen, navigates fax documents, uses tools (zoom, rotate, flip, print, download), and reviews content.
4. Manual indexing and metadata update
   - Scheduler classifies document type and category, enters or updates FIN and clinical metadata, and sets processing status.
5. Case linking
   - System resolves FIN/request relation in mit-surgical.
   - If request exists, document is associated to request attachments.
   - If request does not exist, document remains indexed and link is deferred.
6. Bulk FIN update
   - Scheduler applies one FIN to multiple selected documents in one action.
7. Split document
   - Scheduler splits multi-patient PDF into separate documents; child documents return to queue and parent traceability is preserved.
8. Activity and audit timeline
   - User/admin opens document activity panel to view who changed what and when, including status transitions and metadata edits.

### Functional requirements (explicit + inferred)
- Ingest inbound RightFax PDFs from structured storage path and preserve source metadata.
- Route inbound documents to queue/unit context via fax-number-to-unit mapping.
- Display fax list with performant search/filter/sort/pagination for large datasets.
- Support statuses aligned with operations and UI cards.
- Provide PDF viewer controls: rotate, flip, zoom, print, download.
- Allow indexing of document category, page classification/index tabs, and metadata fields (FIN, patient, DOB, procedure date, surgeon, etc.).
- Support case linkage to mit-surgical surgery requests and attachment visibility in case workflow.
- Support bulk metadata update by selected document IDs.
- Support split operation with lineage (parent/child).
- Capture and expose document activity timeline.
- Enforce role-based access patterns (OR Scheduler, Hospital Viewer, PAT print/download behavior).
- Provide queue/task-card count endpoints optimized for frequent UI polling.

### Non-functional requirements
- Performance: list and search must sustain high historical volume; aggregation counts need caching.
- Scalability: asynchronous ingest and stateless APIs with indexed Mongo queries.
- Reliability: idempotent processing for duplicate storage events and retries.
- Security: role-based scope checks, signed URL for protected file access, non-public bucket access.
- Compliance: audit/compliance logging and immutable activity history.
- Observability: publish operational/compliance events and capture latency/error metrics.
- UX constraints: near-real-time queue freshness, fast list/filter response, clear status semantics.
- Data integrity: split and bulk updates must be consistent and traceable.

### Edge cases, constraints, assumptions
- Duplicate object-finalize events from Cloud Storage.
- Invalid path format or missing metadata tokens (ministry/fax numbers).
- Unknown fax number mapping to queue/unit.
- FIN not found at indexing time.
- One FIN associated to multiple docs or conflicting FIN corrections.
- PDF split with invalid/overlapping page ranges.
- Signed URL expiry during long review sessions.
- Status model mismatch between product labels and current backend enum.
- Assumption: Phase 1 prioritizes manual indexing; AI extraction can follow in Phase 2.

## 2. Technical Architecture and Specifications

### Architecture summary
- Intake: RightFax -> GCS -> Cloud Function (metadata extraction and file move).
- Document domain: dssc-document-service stores document metadata/index/access/storage state in MongoDB and supports file operations.
- Clinical domain: mit-surgical holds surgery requests/units and case linkage context.
- Messaging: Pub/Sub for document status and compliance/metrics patterns.
- Storage: GCS for binaries, MongoDB for metadata/state, Redis cache for hot aggregates (recommended/proposed).

### Required API endpoints (existing vs new)

| Service | Endpoint | Status | Purpose |
|---|---|---|---|
| dssc-document-service | POST /v2/documents | Existing | Signed URL workflow for document save |
| dssc-document-service | GET /v2/documents/{documentId}/meta | Existing | Fetch document metadata |
| dssc-document-service | POST /v2/documents/meta | Existing | Batch metadata retrieval |
| dssc-document-service | PUT /v2/documents/access | Existing | Bulk access updates by identifier |
| dssc-document-service | POST /v1/documents/{documentId}/index | Existing | Index/page metadata on document |
| dssc-document-service | GET /v1/documents/{documentId}/index | Existing | Get index/page metadata |
| dssc-document-service | POST /v1/documents/{documentId}/print | Existing | Print action endpoint |
| mit-surgical | /v2/surgery-requests (GET/POST/PUT base flows) | Existing | Case request lifecycle |
| mit-surgical | /hospital or /hospitals (+ unit lookups) | Existing | Unit/hospital master data for queue display |
| dssc-document-service | GET /v2/documents (search/list with filters) | Proposed extension | Inbox list for fax processing UI |
| dssc-document-service | PATCH /v2/documents/{id}/metadata | New | Save metadata + status changes |
| dssc-document-service | PUT /v2/documents/bulk-metadata | New | Bulk FIN/status update |
| dssc-document-service | GET /v2/documents/counts | New | Task card counts by queue/status |
| dssc-document-service | POST /v2/documents/{id}/split | New | Split PDF into child docs |
| dssc-document-service | GET /v2/documents/{id}/signed-url | New/clarifying | Secure download/print access URL |
| dssc-document-service | GET /v2/documents/{id}/activities | New | Document activity timeline |
| dssc-document-service | PATCH /v2/documents/{id}/view-preferences | New | Rotation/flip state persistence |

### Request/response schemas (recommended)

| API | Request (key fields) | Response (key fields) |
|---|---|---|
| PATCH /v2/documents/{id}/metadata | status, metadata.fin, metadata.patientName, metadata.dob, metadata.procedureDate, metadata.surgeon, category, index[] | id, status, metadata, updatedAt, updatedBy |
| PUT /v2/documents/bulk-metadata | documentIds[], fin, optional status | updatedCount, failedIds[] |
| GET /v2/documents | queueId, status[], dateFrom/dateTo, fin, patient, category, page,size,sort | content[], totalElements, totalPages |
| GET /v2/documents/counts | queueIds[], statusSet | countsByQueueStatus[] |
| POST /v2/documents/{id}/split | splitInstructions[] (page ranges + optional metadata) | parentId, childDocumentIds[], status |
| GET /v2/documents/{id}/activities | paging params | activityEvents[] (actor, action, before/after, timestamp) |

### Events (domain events, pub/sub)
- Existing platform patterns:
  - Document status publication topic pattern.
  - Compliance logging topic pattern.
  - Metrics event topic pattern.
- Fax domain events to formalize:
  - fax.document.ingested
  - fax.document.indexed
  - fax.document.status.changed
  - fax.document.linked
  - fax.document.split
  - fax.document.bulkUpdated
- Event envelope recommendation:
  - eventId, eventType, timestamp, traceId, actor, documentId, ministry, queueId, source, payloadVersion.

### Data models and storage considerations
- Current document entity includes core metadata, status enum, storage, index array, access list, fax numbers, and practice name.
- Backend spec recommends hybrid extension:
  - Root: id, queueId, status, created/updated audit.
  - Nested metadata object: FIN, patient/procedure fields, category, AI fields (future).
  - Index object: page-level classification.
  - View preferences: rotationAngle, isFlipped.
  - Lineage: splitParentId, childIds.
- Required indexes:
  - queueId + status compound.
  - metadata.fin.
  - metadata.patientLastName + metadata.procedureDate (if common filters).
  - createdAt for recency sort.
- Caching:
  - Counts endpoint TTL cache 30-60s to protect Mongo under polling.

### Integration points (internal and external)
- RightFax inbound file source.
- Cloud Function metadata extraction and move.
- dssc-document-service for document lifecycle and operations.
- mit-surgical for units and surgery request linkage.
- Optional future UiPath AI extraction integration.
- GCS for binaries and signed URLs.
- Pub/Sub for lifecycle/compliance/metrics messaging.

### Technologies involved
- Frontend: Fax list + PDF viewer + activity drawer (from Figma structure).
- Backend: Java 17+/21, Spring Boot, Spring Data MongoDB, Spring Security.
- Infrastructure: GCP Cloud Functions Gen2, GCS, Pub/Sub, GKE, MongoDB Atlas, Redis cache.
- PDF operations: Apache PDFBox (split/transform workflows).

### Dependencies, architectural constraints, alignment with existing system patterns
- Align to platform service layering (controller/service/repository, DTO/entity separation).
- Align to REST and pagination conventions.
- Align to compliance logging and metrics topic usage.
- Constraint: authentication and service-to-service auth docs are incomplete; implementation must not assume undocumented trust boundaries.
- Constraint: existing document service status enum differs from product status language and requires mapping strategy.

### Sequence diagrams / step-by-step technical flows

#### A. Inbound intake to queue
```text
RightFax -> GCS(raw path)
GCS event -> Cloud Function
Cloud Function: parse ministry/sender/receiver + attach metadata
Cloud Function -> GCS(destination with metadata)
Document Service consumer -> create Document (initial state) + queue mapping
Document Service -> publish status/compliance events
UI -> list endpoint shows waiting/review queue
```

#### B. Manual indexing and case link
```text
Scheduler -> UI -> GET document list/filter
Scheduler -> UI -> open PDF + metadata panel
UI -> PATCH document metadata/status
UI -> mit-surgical lookup by FIN/request
If request exists: link attachment to request
If request absent: retain indexed doc, retry/defer link
UI -> GET activity timeline
```

#### C. Split document
```text
Scheduler -> POST split(docId, page ranges)
Service: fetch PDF from GCS -> split via PDFBox
Service: upload child files -> create child docs -> update parent lineage/status
Service -> emit split/status/compliance events
UI refreshes list + counts + timeline
```

## 3. Monitoring and Observability

### Logging requirements
- Log at ingestion, metadata update, split, link, bulk update, signed URL generation.
- Levels:
  - INFO: lifecycle transitions and successful operations with IDs.
  - WARN: recoverable parsing/mapping issues and partial bulk failures.
  - ERROR: failed persistence, failed split/upload, integration failures.
- Correlation:
  - propagate traceparent or traceId across HTTP and event boundaries.
  - include documentId, eventId, queueId, ministry, requestId.
- PII/PHI handling:
  - do not log full patient identifiers, DOB, or full FIN in plaintext.
  - use masked FIN and role-based secure views.
- Compliance:
  - publish immutable audit records to compliance logging pipeline for access and mutation events.

### Metrics to track

| Category | Metric |
|---|---|
| Business KPI | Average fax handling time (received -> closed) |
| Business KPI | Auto/assisted classification rate (future AI phase) |
| Business KPI | Throughput per scheduler, per queue, per day |
| Business KPI | Linked-to-case rate and time-to-link |
| System | Intake success/failure rate from Cloud Function |
| System | Metadata update success/failure and p95 latency |
| System | Search/list p95 latency and error rate |
| System | Split success/failure and processing time |
| System | Pub/Sub consumer lag/retry/DLQ counts |
| System | Signed URL generation failures |
| System | Cache hit ratio for counts endpoint |

### Alerts (thresholds and scenarios)
- Ingestion failure spike: >5% failures over 5 minutes.
- Queue growth anomaly: waiting backlog above historical threshold (for example >2x 7-day hourly baseline).
- API latency: p95 > 1.5s for list/filter for 15 minutes.
- Split failures: >2% over 15 minutes.
- Consumer lag: sustained lag >10 minutes.
- Compliance logging publish failures: sustained failure >2 minutes (high severity).

### Dashboards and recommended monitoring tools
- Cloud Monitoring dashboard:
  - intake pipeline health, queue volume, status transitions, endpoint latency/error, Pub/Sub lag.
- Operational dashboard:
  - queue counts by unit, aging buckets, scheduler throughput, link completion rate.
- Compliance dashboard:
  - activity event volume, anomalous access patterns, failed audit publishes.

### Required updates to existing monitoring frameworks
- Add explicit Fax Management event taxonomy and metric dimensions (ministry, queueId, status).
- Add structured logging schema shared across Cloud Function and services.
- Add SLI/SLO definitions for inbox freshness and metadata save latency.
- Add alert runbooks for ingestion, backlog, split, and linkage failures.

## 4. Contradictions, Missing Information, and Suggested Improvements

### Contradictions called out explicitly
1. PRD emphasizes AI extraction and boarding-sheet identification; backend spec explicitly removes AI from initial scope and favors manual indexing.
2. Prompt references PRD and backend spec using the same file path, but repository has separate PRD and backend spec files.
3. Backend spec references a dedicated attachment endpoint path that is not clearly present as a standalone route in current mit-surgical contracts; attachment behavior appears embedded in surgery-request request/update flows.
4. Product statuses (Waiting, Reviewed, Closed, Current) do not match current document-service enum values (CLEAN, QUARANTINE, UNPROCESSED, PROCESSING) and require harmonization.

### Missing information / unclear requirements
- Canonical status transition state machine and invalid transition handling.
- Exact queue mapping source-of-truth ownership and update process for fax number routing.
- Duplicate-event and idempotency guarantees across Cloud Function and document creation.
- Detailed auth model for user and service-to-service paths (docs contain placeholders).
- PHI retention, masking, and purge policy for activity logs and metadata.
- Final source of truth for case-linking when FIN changes after initial link.
- OpenAPI-level contract definitions for new endpoints and event schemas.

### Improvements and optimizations
1. Define Phase 1 as manual indexing + linkage + observability; Phase 2 adds AI extraction.
2. Publish a status mapping contract between UI statuses and backend persistence statuses.
3. Add explicit endpoint and event contracts before implementation sprint.
4. Add idempotency key strategy for ingestion and split operations.
5. Finalize RBAC matrix for OR Scheduler, PAT, and Hospital Viewer actions.

## 5. Implementation Readiness for Engineering, QA, and Design

### Engineering readiness
- Contract-first implementation with OpenAPI + event schemas before coding.
- State model hardening with explicit transition rules and optimistic concurrency.
- Performance guardrails in first increment (indexes + counts cache).

### QA readiness
- Unit tests for status transitions, routing, metadata validators, split range validation.
- Integration tests for ingest, metadata save, case-linking, and Pub/Sub event publication.
- E2E tests for list/filter, viewer operations, bulk FIN update, split lifecycle, and activity timeline.

### Design readiness
- Use Figma list + PDF viewer + activity panel as baseline.
- Add clear status chips/badges with explicit transition affordances.
- Include error and retry states for linking, split conflicts, and stale signed URLs.

---

## Appendix: Source Inputs Reviewed
- features/fax-management/Fax-Management-PRD.md
- features/fax-management/Backend-Technical-Specification-TXAUS-Fax-Management.md
- features/fax-management/Figma-link.md
- docs/architecture/*
- docs/contracts/*
- docs/infrastructure/*
- docs/patterns/*
- docs/services/*
