# Feature Specification: DSSC-8643
# SSM API — Practice `faxNumber` Field & Endpoint by Ministry

**Service:** `mit-surgical`
**Epic:** Fax Management — Epic 1 (RightFax Ingestion) / Epic 2 (Core API)
**Story Type:** Backend API
**Related Spec:** [Backend Technical Specification - TXAUS Fax Management](../../../../../../Documents/Fax%20Management/Backend%20Technical%20Specification%20-%20TXAUS%20Fax%20Management.md)

---

## 1. Background & Business Context

RightFax deposits incoming fax files in GCS using the path pattern:

```
/{ministry}/{receiverFaxNumber}/{senderFaxNumber}/yyyy-mm-dd/{fileName}.pdf
```

The `senderFaxNumber` segment identifies the **sending practice** (the surgeon's office). The Document Service extracts this number from the path and must resolve it to the correct `Practice` record in mit-surgical to:

- Display the sending practice name and details in the Fax Management inbox UI.
- Support routing and association of faxes with the correct clinical context.

Currently, the `Practice` entity in mit-surgical has **no `faxNumber` field**, making resolution impossible. Additionally, there is **no endpoint to list practices filtered by ministry**, which the Document Service needs to perform efficient lookups within a ministry boundary.

---

## 2. Goals

1. Add a `faxNumber` field to the `Practice` data model so individual practices can be identified by their outbound fax number.
2. Expose a new read endpoint `GET /practice/ministry/{ministry}` to allow callers (Document Service, UI) to retrieve all practices belonging to a specific ministry.

---

## 3. Out of Scope

- Automated population of `faxNumber` for existing practices (manual data entry by admins via existing `PUT /practice/` endpoint).
- Any changes to `dssc-document-service` or the Cloud Function (covered in separate stories).
- UI changes.
- New OAuth2 scopes (reuse existing `dssc_schedule_app.practice.read`).

---

## 4. Data Model Change

### 4.1 `Practice` Entity — add `faxNumber`

| Field | Type | Required | Indexed | Notes |
|---|---|---|---|---|
| `faxNumber` | `String` | No | No | E.164-compatible format recommended (e.g. `+12223334444`). No uniqueness constraint — two practices may share a fax line. |

**MongoDB migration:** Not required. MongoDB is schema-less; existing documents will return `null` for `faxNumber` until updated.

**Files changed:**
- `entity/Practice.java` — add field + getter/setter
- `dto/PracticeDTO.java` — add field + getter/setter

---

## 5. New API Endpoint

### `GET /practice/ministry/{ministry}`

#### Description
Returns all practices whose `primaryMinistry` field matches the given ministry identifier.

#### Request

| Element | Value |
|---|---|
| Method | `GET` |
| Path | `/practice/ministry/{ministry}` |
| Auth Scope | `SCOPE_dssc_schedule_app.practice.read` |
| Path param | `ministry` — string ministry identifier (e.g. `TXAUS`) |
| Request body | None |

#### Response

| HTTP Status | Condition | Body |
|---|---|---|
| `200 OK` | One or more practices found | `List<PracticeDTO>` (JSON array) |
| `204 No Content` | No practices match the ministry | Empty |
| `400 Bad Request` | Malformed request | `AscensionFault` |
| `401 Unauthorized` | Missing or invalid token | `AscensionFault` |
| `403 Forbidden` | Token lacks required scope | `AscensionFault` |

#### Example Response Body (`200`)

```json
[
  {
    "id": "64b1f...",
    "name": "Austin Surgeons Group",
    "address": "1234 Main St",
    "city": "Austin",
    "state": "TX",
    "zipCode": "78701",
    "euid": "P-00123",
    "faxNumber": "+15125550101",
    "primaryMinistry": "TXAUS",
    "primaryHospital": "Ascension Seton Medical Center",
    "distributionEmail": "scheduling@austinsurgeons.com"
  }
]
```

---

## 6. Acceptance Criteria

### AC-1: `faxNumber` stored and returned on Practice

**Given** a Practice document is created or updated via `POST /practice/` or `PUT /practice/` with a `faxNumber` value  
**When** the practice is retrieved via `GET /practice/{id}` or `GET /practice/euid/{euid}`  
**Then** the response includes the `faxNumber` field with the saved value

---

### AC-2: `faxNumber` is optional

**Given** a Practice is created without a `faxNumber` field  
**When** the practice is retrieved  
**Then** `faxNumber` is either absent or `null` in the response, and no validation error is thrown

---

### AC-3: `GET /practice/ministry/{ministry}` returns matching practices

**Given** practices exist in the database with `primaryMinistry = "TXAUS"`  
**When** a caller with `SCOPE_dssc_schedule_app.practice.read` sends `GET /practice/ministry/TXAUS`  
**Then** the response is `200 OK` with a JSON array containing only practices whose `primaryMinistry` is `TXAUS`

---

### AC-4: `faxNumber` is included in the ministry endpoint response

**Given** a practice with `primaryMinistry = "TXAUS"` has a `faxNumber` set  
**When** `GET /practice/ministry/TXAUS` is called  
**Then** each returned `PracticeDTO` includes the `faxNumber` field

---

### AC-5: Returns `204` when no practices match the ministry

**Given** no practices exist with `primaryMinistry = "UNKNOWN"`  
**When** `GET /practice/ministry/UNKNOWN` is called  
**Then** the response is `204 No Content` with an empty body

---

### AC-6: Endpoint requires authentication

**Given** a request is made to `GET /practice/ministry/{ministry}` without a valid Bearer token  
**Then** the response is `401 Unauthorized`

---

### AC-7: Endpoint requires correct OAuth2 scope

**Given** a request is made with a valid token that lacks `SCOPE_dssc_schedule_app.practice.read`  
**Then** the response is `403 Forbidden`

---

## 7. Technical Implementation Summary

See [DSSC-8643-practice-fax-endpoint.md](./DSSC-8643-practice-fax-endpoint.md) for the full code-level implementation plan.

**Files to change (8 total):**

```
mit-surgical/src/main/java/org/ascension/swe/surgical/procedure/
├── entity/Practice.java
├── dto/PracticeDTO.java
├── repository/IPracticeRepository.java
├── repository/impl/PracticeRepository.java
├── service/IPracticeService.java
├── service/impl/PracticeServiceImpl.java
├── resource/contract/PracticeContract.java
└── resource/PracticeController.java
```

---

## 8. Testing Requirements

| Test | Type | File |
|---|---|---|
| `faxNumber` persists and is returned | Unit | `PracticeServiceImplTest` |
| `findPracticesByMinistry()` returns correct list | Unit | `PracticeRepositoryTest` |
| `findAllPracticesByMinistry()` maps to DTOs correctly | Unit | `PracticeServiceImplTest` |
| `GET /practice/ministry/{ministry}` returns `200` with data | Unit | `PracticeControllerTest` |
| `GET /practice/ministry/{ministry}` returns `204` on no match | Unit | `PracticeControllerTest` |
| End-to-end ministry lookup with faxNumber populated | Integration | `PracticeControllerIT` |

---

## 9. Definition of Done

- [ ] `faxNumber` field added to `Practice` entity and `PracticeDTO`
- [ ] `GET /practice/ministry/{ministry}` endpoint implemented across all 4 layers
- [ ] All 7 acceptance criteria pass
- [ ] Unit tests added/updated with no regression
- [ ] OpenAPI docs updated (auto-generated via `PracticeContract` annotations)
- [ ] Code reviewed and merged to the feature branch
- [ ] Deployed to QA and validated against a practice record with a `faxNumber`
