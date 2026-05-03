# Feature Specification: DSSC-8575
# DS - API — Search for a List of Faxes

**Service:** `dssc-document-service`
**Epic:** Fax Management — Epic 2 (Core API & Integration) / Story 2.1 (Inbox Search and Filtering)
**Story Type:** Backend API
**Related Spec:** [Backend Technical Specification - TXAUS Fax Management](../../../../../../Documents/Fax%20Management/Backend%20Technical%20Specification%20-%20TXAUS%20Fax%20Management.md)

---

## 1. Background & Business Context

The Fax Management inbox UI allows OR Schedulers to view and triage inbound faxes across one or more OR units (queues). Each user's accessible queues are determined by their assigned facility fax numbers. The inbox must support:

- Filtering by queue (one or more `facilityFaxNumber` values)
- Filtering by review status (`WAITING`, `REVIEWED`, `DATA_CONFLICT`, `CLOSED`)
- Filtering by category (`BOARDING`, `SUPPORT`, or uncategorised)
- Optional free-text / date search on metadata fields
- Sortable, paginated results
- A real-time status count breakdown for the tab bar (all counts per `ReviewStatus` for the current user's queues)

Currently, no fax-specific search endpoint exists in `dssc-document-service`. The existing `GET /v2/documents` and related endpoints are designed for the document upload/management workflow and do not model fax-specific fields such as `fin` or `procedureDate`.

---

## 2. Goals

1. Create a new `GET /v1/faxes/search` endpoint that the Fax Management UI consumes as its primary inbox data source.
2. Return a paginated list of fax summaries with all fields required by the inbox table.
3. Include a `counts` breakdown by `ReviewStatus` (scoped to the queried fax numbers, not to the page filter) so the UI can render tab counts in a single request.
4. Add `fin` and `procedureDate` to `DocumentEntity` and its associated DTO so they can be stored, searched, and returned.

---

## 3. Out of Scope

- Changes to existing `/v1/documents` or `/v2/documents` endpoints.
- Atlas Search index setup (separate ticket per backend spec notes).
- Any caching layer — counts are computed per-request in this story; a caching story may follow.
- UI changes.
- Any write operations (saving `fin`, `procedureDate` is covered by a separate metadata update story).
- JWT/authentication infrastructure — existing scope enforcement is reused unchanged.

---

## 4. Current State

### 4.1 `DocumentEntity.java` — existing fax-relevant fields

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | MongoDB `_id` |
| `createdAt` | `LocalDateTime` | Corresponds to "Received" column |
| `reviewStatus` | `ReviewStatus` | `WAITING`, `REVIEWED`, `DATA_CONFLICT`, `CLOSED` |
| `category` | `DocumentCategoryEnum` | `BOARDING`, `SUPPORT` (nullable) |
| `practiceName` | `String` | Resolved at ingest from sender fax number |
| `patientFirstName` | `String` | |
| `patientLastName` | `String` | |
| `dob` | `LocalDate` | |
| `note` | `String` | |
| `facilityFaxNumber` | `String` | Receiver fax number — used as queue identifier |
| `practiceFaxNumber` | `String` | Sender fax number |

### 4.2 Missing fields

| Field | Notes |
|---|---|
| `fin` | FIN (account number) — not yet stored in entity |
| `procedureDate` | Procedure/surgery date — not yet stored in entity |

> `identifier` is **not** the FIN. It is an internal GCS signed-URL access token and must not be repurposed.

### 4.3 `DocumentCategoryEnum`

```java
public enum DocumentCategoryEnum { BOARDING, SUPPORT }
```

Documents ingested from RightFax have no category yet (`null`). The story uses the string `"NULL"` in the request to represent filtering for uncategorised documents.

### 4.4 No existing fax search endpoint

`DocumentV2Contract` (`/v2/documents`) provides document CRUD and signed-URL operations only. There is no search/filter endpoint compatible with the inbox use case.

---

## 5. Data Model Change

### 5.1 New fields on `DocumentEntity.java`

| Field | Type | Required | Source | Notes |
|---|---|---|---|---|
| `fin` | `String` | No | Metadata update | FIN / account number entered by OR Scheduler |
| `procedureDate` | `LocalDate` | No | Metadata update | Procedure date entered by OR Scheduler |

**MongoDB migration:** Not required. Existing documents will return `null` for both fields until updated via the metadata update endpoint (separate story).

**Corresponding DTO update:** Both fields must also be added to `DocumentDTO.java` for the existing toEntity/mapping flow to support them when they are written.

---

## 6. New API Endpoint

### 6.1 Summary

| Element | Value |
|---|---|
| Method | `GET` |
| Path | `/v1/faxes/search` |
| Auth Scope | `SCOPE_dssc_schedule_app.document.read` or `SCOPE_CLIENT_dssc_document.read` (reuse `SCOPE_READ` from `DocumentContract`) |
| Content-Type | N/A (query parameters only) |

### 6.2 Query Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `faxNumbers` | `String` (CSV) | Yes | Comma-separated list of facility fax numbers scoping the query to the caller's queues, e.g. `5122222222,5122121234` |
| `status` | `String` (CSV) | Yes | Comma-separated `ReviewStatus` values. UI sends `WAITING,REVIEWED,DATA_CONFLICT` for the "Current" tab |
| `category` | `String` (CSV) | Yes | Comma-separated values: `BOARDING`, `SUPPORT`, or `NULL` (represents uncategorised). UI sends all three for "All" |
| `patientName` | `String` | No | Case-insensitive partial match against `patientFirstName` or `patientLastName` |
| `DOB` | `String` (date) | No | Exact match against `dob` — format `yyyy-MM-dd` |
| `fin` | `String` | No | Exact match against `fin` |
| `practiceName` | `String` | No | Case-insensitive partial match against `practiceName` |
| `procedureDate` | `String` (date) | No | Exact match against `procedureDate` — format `yyyy-MM-dd` |
| `sortModel` | `String` | Yes | Field and direction, e.g. `createdDate:desc`. Field `createdDate` maps to entity field `createdAt` |
| `page` | `int` | Yes | Zero-based page number. If the requested page exceeds the last page, the last page is returned |
| `size` | `int` | Yes | Page size (number of results per page) |

**Example request:**
```
GET /v1/faxes/search?faxNumbers=5122222222,5122121234&status=WAITING,REVIEWED,DATA_CONFLICT&category=BOARDING,SUPPORT,NULL&sortModel=createdDate:desc&page=0&size=10
```

### 6.3 Response

**HTTP `200 OK`:**

```json
{
  "faxes": [
    {
      "id": "68f905be977d8a3655d6ac6f",
      "createdDate": "2026-03-26 14:30:12",
      "procedureDate": "2026-03-26",
      "practiceName": "Urology Associates, P.C.",
      "fin": "570423123",
      "firstName": "John",
      "lastName": "Doe",
      "DOB": "2000-01-01",
      "category": "BOARDING",
      "note": "A note about something...",
      "reviewStatus": "REVIEWED"
    }
  ],
  "totalCount": 19,
  "counts": {
    "DATA_CONFLICT": 3,
    "WAITING": 12,
    "REVIEWED": 3,
    "CLOSED": 1
  },
  "page": 0
}
```

> All fax fields except `id`, `createdDate`, and `reviewStatus` are nullable. `category` is `null` for documents not yet categorised; `counts` covers all four `ReviewStatus` values for the caller's queues regardless of the current `status` filter.

**Other HTTP responses:**

| Status | Condition |
|---|---|
| `400 Bad Request` | Missing required parameters or malformed date/sort format |
| `401 Unauthorized` | Missing or invalid token |
| `403 Forbidden` | Token lacks required scope |
| `500 Internal Server Error` | Unexpected error |

---

## 7. Query Design

### 7.1 Mandatory criteria (always applied to both main query and counts query)

- `facilityFaxNumber IN faxNumbers` — access boundary; scopes results to the caller's queues

### 7.2 Main query criteria (applied to paginated results only)

- `reviewStatus IN status`
- `category`: parse each CSV value as follows:
  - `"NULL"` → `Criteria.where("category").is(null)`
  - `"BOARDING"` / `"SUPPORT"` → map to `DocumentCategoryEnum`
  - When multiple values are present (including `NULL`), combine with `$in` for enum values and add the null check with `$or`
- `patientName` (if present) → `$or [ { patientFirstName: { $regex: value, $options: "i" } }, { patientLastName: { $regex: value, $options: "i" } } ]`
- `DOB` (if present) → `{ dob: LocalDate.parse(value) }`
- `fin` (if present) → `{ fin: value }` (exact)
- `practiceName` (if present) → `{ practiceName: { $regex: value, $options: "i" } }`
- `procedureDate` (if present) → `{ procedureDate: LocalDate.parse(value) }`

### 7.3 Sorting

Parse `sortModel` as `<field>:<direction>`:

| Request field | Entity field | Sort |
|---|---|---|
| `createdDate` | `createdAt` | `asc` / `desc` |

Default to `createdAt:desc` if `sortModel` is unrecognised. Additional sortable fields may be added in future iterations.

### 7.4 Pagination

- Apply `Query.with(PageRequest.of(page, size, sort))`
- Before returning, compute `lastPage = max(0, ceil(totalCount / size) - 1)`. If `page > lastPage`, re-run with `page = lastPage` and return that page number in the response.

### 7.5 Counts aggregation

Run a **separate aggregation** with only the mandatory `facilityFaxNumber IN faxNumbers` filter, then `$group` by `reviewStatus` and `$count`:

```
$match: { facilityFaxNumber: { $in: faxNumbers } }
$group: { _id: "$reviewStatus", count: { $sum: 1 } }
```

Map results into a fixed-shape `counts` object with all four `ReviewStatus` keys, defaulting absent statuses to `0`. This ensures tab counts are always stable regardless of the active status/category filter.

---

## 8. New Components

### 8.1 `model/dto/fax/FaxSearchRequest.java`

Request DTO binding all query parameters:

```java
private String faxNumbers;       // CSV, required
private String status;           // CSV, required
private String category;         // CSV, required
private String patientName;      // optional
private String dob;              // optional (String, parsed to LocalDate)
private String fin;              // optional
private String practiceName;     // optional
private String procedureDate;    // optional (String, parsed to LocalDate)
private String sortModel;        // required, e.g. "createdDate:desc"
private int page;                // required
private int size;                // required
```

### 8.2 `model/dto/fax/FaxSummaryDTO.java`

Per-item response DTO:

```java
private String id;
@JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
private LocalDateTime createdDate;
@JsonFormat(pattern = "yyyy-MM-dd")
private LocalDate procedureDate;
private String practiceName;
private String fin;
private String firstName;
private String lastName;
@JsonFormat(pattern = "yyyy-MM-dd")
private LocalDate dob;
private DocumentCategoryEnum category;
private String note;
private ReviewStatus reviewStatus;
```

### 8.3 `model/dto/fax/FaxStatusCountsDTO.java`

Status count breakdown:

```java
private int waiting;
private int reviewed;
private int dataConflict;
private int closed;
```

### 8.4 `model/dto/fax/FaxSearchResponse.java`

Wrapper response:

```java
private List<FaxSummaryDTO> faxes;
private long totalCount;
private FaxStatusCountsDTO counts;
private int page;
```

### 8.5 `resource/FaxContract.java`

New contract interface annotated with `@RequestMapping("/v1/faxes")`:

```java
@GetMapping("/search")
@PreAuthorize(SCOPE_READ)   // reuse constant from DocumentContract
ResponseEntity<FaxSearchResponse> searchFaxes(FaxSearchRequest request);
```

### 8.6 `resource/impl/FaxController.java`

`@RestController` implementing `FaxContract`, delegating to `FaxSearchService`.

### 8.7 `service/FaxSearchService.java`

Contains two methods:

- `searchFaxes(FaxSearchRequest)` — builds Criteria query, executes paginated `MongoTemplate.find()`, fetches total count via `MongoTemplate.count()`, fetches status counts via aggregation, assembles `FaxSearchResponse`.
- Private `buildSearchCriteria(FaxSearchRequest)` — returns `Criteria` from all filter params.

Uses `MongoTemplate` directly (consistent with `DocumentRepository` pattern). Does **not** use Atlas Search — Criteria-based queries only.

---

## 9. API Response — Full Example

**Request:**
```
GET /v1/faxes/search?faxNumbers=5122222222&status=WAITING,REVIEWED&category=BOARDING,SUPPORT,NULL&sortModel=createdDate:desc&page=0&size=2
```

**Response:**
```json
{
  "faxes": [
    {
      "id": "68f905be977d8a3655d6ac6f",
      "createdDate": "2026-03-26 14:30:12",
      "procedureDate": "2026-03-26",
      "practiceName": "Urology Associates, P.C.",
      "fin": "570423123",
      "firstName": "John",
      "lastName": "Doe",
      "DOB": "2000-01-01",
      "category": "BOARDING",
      "note": null,
      "reviewStatus": "REVIEWED"
    },
    {
      "id": "68f905be977d8a3655d6ac70",
      "createdDate": "2026-03-25 09:11:00",
      "procedureDate": null,
      "practiceName": null,
      "fin": null,
      "firstName": null,
      "lastName": null,
      "DOB": null,
      "category": null,
      "note": null,
      "reviewStatus": "WAITING"
    }
  ],
  "totalCount": 19,
  "counts": {
    "DATA_CONFLICT": 3,
    "WAITING": 12,
    "REVIEWED": 3,
    "CLOSED": 1
  },
  "page": 0
}
```

---

## 10. Acceptance Criteria

### AC-1: Returns paginated list filtered by fax numbers and status

**Given** documents exist in MongoDB with `facilityFaxNumber = "5122222222"` and `reviewStatus = "WAITING"`  
**When** `GET /v1/faxes/search?faxNumbers=5122222222&status=WAITING&category=BOARDING,SUPPORT,NULL&sortModel=createdDate:desc&page=0&size=10` is called with valid auth  
**Then** response is `200 OK` containing only documents matching the fax number and status, up to `size` items

---

### AC-2: Category `NULL` matches uncategorised documents

**Given** a document has `category = null` in MongoDB  
**When** `category=NULL` is included in the request  
**Then** the uncategorised document is included in the results

---

### AC-3: Category `BOARDING` / `SUPPORT` filter works correctly

**Given** documents with categories `BOARDING` and `SUPPORT` exist  
**When** `category=BOARDING` is sent  
**Then** only `BOARDING` documents are returned and `SUPPORT` documents are excluded

---

### AC-4: `counts` reflects queue totals, not current page filter

**Given** the caller's queue has `WAITING: 12`, `REVIEWED: 3`, `DATA_CONFLICT: 3`, `CLOSED: 1`  
**When** `status=WAITING` is sent (filtering results to WAITING only)  
**Then** the `counts` object still returns the full breakdown `{ WAITING: 12, REVIEWED: 3, DATA_CONFLICT: 3, CLOSED: 1 }`

---

### AC-5: Optional filters narrow results correctly

**Given** documents with different `practiceName`, `fin`, `patientFirstName`/`patientLastName`, `dob`, and `procedureDate` values  
**When** any optional filter parameter is supplied  
**Then** only documents matching that filter are returned

---

### AC-6: `patientName` filter is case-insensitive and partial

**Given** a document has `patientFirstName = "John"` and `patientLastName = "Doe"`  
**When** `patientName=joh` is sent  
**Then** the document is included in results

---

### AC-7: Page out-of-bounds returns last page

**Given** `totalCount = 19` and `size = 10` (2 pages: 0 and 1)  
**When** `page=5` is requested  
**Then** the response returns the items from page 1 and `"page": 1`

---

### AC-8: Sorted results respect `sortModel`

**Given** multiple documents with different `createdAt` values  
**When** `sortModel=createdDate:desc` is sent  
**Then** documents are returned in descending order of `createdAt`

---

### AC-9: Endpoint requires authentication

**Given** a request is made without a valid Bearer token  
**Then** the response is `401 Unauthorized`

---

### AC-10: Endpoint requires correct OAuth2 scope

**Given** a request is made with a valid token that has neither `SCOPE_dssc_schedule_app.document.read` nor `SCOPE_CLIENT_dssc_document.read`  
**Then** the response is `403 Forbidden`

---

### AC-11: Missing required parameters return 400

**Given** a request omits `faxNumbers`, `status`, `category`, `sortModel`, `page`, or `size`  
**Then** the response is `400 Bad Request`

---

## 11. Files Changed Summary

```
dssc-document-service/src/main/java/org/ascension/swe/document/
├── model/entity/DocumentEntity.java                     → add fin (String), procedureDate (LocalDate)
├── model/dto/DocumentDTO.java                           → add fin (String), procedureDate (LocalDate)
├── model/dto/fax/FaxSearchRequest.java                  → new request DTO
├── model/dto/fax/FaxSummaryDTO.java                     → new per-item response DTO
├── model/dto/fax/FaxStatusCountsDTO.java                → new counts DTO
├── model/dto/fax/FaxSearchResponse.java                 → new wrapper response DTO
├── resource/FaxContract.java                            → new contract interface
├── resource/impl/FaxController.java                     → new REST controller
└── service/FaxSearchService.java                        → new service: search + counts aggregation
```

**Total: 9 files (7 new, 2 modified)**

---

## 12. Testing Requirements

| Test | Type | File |
|---|---|---|
| Returns only documents matching `faxNumbers` | Unit | `FaxSearchServiceTest` |
| `status` filter correctly maps CSV to `ReviewStatus` enum | Unit | `FaxSearchServiceTest` |
| `category=NULL` matches null-category documents | Unit | `FaxSearchServiceTest` |
| `category=BOARDING` excludes `SUPPORT` and null documents | Unit | `FaxSearchServiceTest` |
| `counts` is scoped to fax numbers only, not status/category filter | Unit | `FaxSearchServiceTest` |
| Optional filters (`patientName`, `fin`, `DOB`, `practiceName`, `procedureDate`) each narrow results | Unit | `FaxSearchServiceTest` |
| `patientName` is case-insensitive partial match on both first and last name | Unit | `FaxSearchServiceTest` |
| Page out-of-bounds clamps to last page and returns correct `page` value | Unit | `FaxSearchServiceTest` |
| `sortModel=createdDate:desc` returns results in correct order | Unit | `FaxSearchServiceTest` |
| `GET /v1/faxes/search` with valid params returns `200` and correct response shape | Integration | `FaxControllerIT` |
| Missing required parameter returns `400` | Integration | `FaxControllerIT` |
| Missing auth token returns `401` | Integration | `FaxControllerIT` |
| Wrong scope returns `403` | Integration | `FaxControllerIT` |

---

## 13. Definition of Done

- [ ] `fin` and `procedureDate` fields added to `DocumentEntity` and `DocumentDTO`
- [ ] All four fax DTO classes created
- [ ] `FaxContract` and `FaxController` created with `GET /v1/faxes/search`
- [ ] `FaxSearchService` implements paginated Criteria query + counts aggregation
- [ ] Category `NULL` handling correctly matches null-category documents
- [ ] Page out-of-bounds handled — last page returned without error
- [ ] All 11 acceptance criteria pass
- [ ] Unit and integration tests added
- [ ] OpenAPI docs auto-generated via contract annotations
- [ ] Code reviewed and merged to feature branch
- [ ] Deployed to QA and validated end-to-end with the Fax Management UI

---

## 14. Open Questions

| # | Question | Owner |
|---|---|---|
| 1 | Should `counts` be scoped strictly to `faxNumbers` only, or should it also respect the `category` filter (e.g., count only `BOARDING` faxes per status)? Current assumption: fax-numbers only so tab counts are stable. | Product + Backend |
| 2 | Should `sortModel` support fields other than `createdDate` (e.g., `procedureDate`, `practiceName`)? | UI + Backend |
| 3 | Is an exact `fin` match sufficient, or should it also support partial / prefix matching (e.g., for partial FIN entry in the search box)? | Product |
| 4 | Should `faxNumbers` be derived from the JWT claims (from the user's unit assignments) rather than being a caller-supplied parameter, to prevent a user querying queues they don't own? | Security + Backend |
| 5 | What is the expected `size` range? Is a maximum page size cap needed (e.g., `max=100`) to protect MongoDB? | Backend |
