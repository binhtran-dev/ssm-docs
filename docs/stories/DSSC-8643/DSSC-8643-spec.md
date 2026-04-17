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
2. Extend the existing `GET /practices` endpoint to support a new optional `primaryMinistry` query parameter, allowing callers (Document Service, UI) to retrieve practices filtered by ministry.

---

## 3. Out of Scope

- Automated population of `faxNumber` for existing practices (manual data entry by admins via existing `PUT /practice/` endpoint).
- Any changes to `dssc-document-service` or the Cloud Function (covered in separate stories).
- UI changes.
- New OAuth2 scopes (reuse existing scopes — see §5.3).
- Creating a new endpoint (reuse `GET /practices`).
- Changes to `userprofile/dto/user/PracticeDTO.java` — that DTO represents a user's linked practice reference (fields: `id`, `surgeons`, `primary`) and has no relation to the practice listing endpoint.
- JWT/authentication infrastructure — existing `ClientAuthenticationToken` wiring via `ascensionid-b2c-sdk` and `@PreAuthorize` on the contract interface is already in place; no changes needed.

---

## 4. Data Model Change

### 4.1 `Practice` Entity — add `faxNumber`

| Field | Type | Required | Indexed | Notes |
|---|---|---|---|---|
| `faxNumber` | `String` | No | No | E.164-compatible format recommended (e.g. `+12223334444`). No uniqueness constraint — two practices may share a fax line. |

**MongoDB migration:** Not required. MongoDB is schema-less; existing documents will return `null` for `faxNumber` until updated.

**Files changed:**
- `entity/Practice.java` — add field + getter/setter
- `procedure/dto/PracticeDTO.java` — add field + getter/setter

> `userprofile/dto/user/PracticeDTO.java` — **no change needed.** This is a separate DTO used only to represent a practice reference on a user profile (`id`, `surgeons`, `primary`). It is not related to the practice listing endpoints.

---

## 5. Endpoint Change — `GET /practices`

### 5.1 Description

The existing `GET /practices` (also `/practice`) endpoint already accepts arbitrary query parameters passed as MongoDB field criteria via `findAllPracticesByParameter`. The `primaryMinistry` filter is added as a **new named query parameter**.

### 5.2 Request

| Element | Value |
|---|---|
| Method | `GET` |
| Path | `/practices` (or `/practice`) |
| Auth Scopes | `SCOPE_dssc_schedule_app.practice.read` **or** `SCOPE_dssc_schedule_app.surgery_schedule.read` (either grants access) |
| Query params | `primaryMinistry` *(optional)* — ministry identifier string, e.g. `TXAUS`. Other existing params still supported. |
| Request body | None |

**Example request:**
```
GET /practices?primaryMinistry=TXAUS
```

### 5.3 Authorization

The `@PreAuthorize` on `getAllPractice` in `PracticeContract.java` is updated to accept **either** scope:

```java
@PreAuthorize("hasAnyAuthority('SCOPE_dssc_schedule_app.practice.read', 'SCOPE_dssc_schedule_app.surgery_schedule.read')")
```

No changes to JWT infrastructure — the existing `ClientAuthenticationToken` / `ascensionid-b2c-sdk` wiring handles token validation and scope extraction.

### 5.4 Response

| HTTP Status | Condition | Body |
|---|---|---|
| `200 OK` | One or more practices found | `List<PracticeDTO>` (JSON array) |
| `204 No Content` | No practices match | Empty |
| `400 Bad Request` | Malformed request | `AscensionFault` |
| `401 Unauthorized` | Missing or invalid token | `AscensionFault` |
| `403 Forbidden` | Token lacks required scope | `AscensionFault` |

**Example `200` response:**

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

### AC-3: `GET /practices?primaryMinistry=TXAUS` returns matching practices

**Given** practices exist in the database with `primaryMinistry = "TXAUS"`  
**When** a caller with `SCOPE_dssc_schedule_app.practice.read` or `SCOPE_dssc_schedule_app.surgery_schedule.read` sends `GET /practices?primaryMinistry=TXAUS`  
**Then** the response is `200 OK` with a JSON array containing only practices whose `primaryMinistry` is `TXAUS`

---

### AC-4: `faxNumber` is included in the ministry-filtered response

**Given** a practice with `primaryMinistry = "TXAUS"` has a `faxNumber` set  
**When** `GET /practices?primaryMinistry=TXAUS` is called  
**Then** each returned `PracticeDTO` includes the `faxNumber` field

---

### AC-5: Returns `204` when no practices match the ministry

**Given** no practices exist with `primaryMinistry = "UNKNOWN"`  
**When** `GET /practices?primaryMinistry=UNKNOWN` is called  
**Then** the response is `204 No Content` with an empty body

---

### AC-6: Endpoint requires authentication

**Given** a request is made to `GET /practices?primaryMinistry=TXAUS` without a valid Bearer token  
**Then** the response is `401 Unauthorized`

---

### AC-7: Endpoint requires correct OAuth2 scope

**Given** a request is made with a valid token that has neither `SCOPE_dssc_schedule_app.practice.read` nor `SCOPE_dssc_schedule_app.surgery_schedule.read`  
**Then** the response is `403 Forbidden`

---

## 7. Technical Implementation Summary

**Files to change (3 total):**

```
mit-surgical/src/main/java/org/ascension/swe/surgical/procedure/
├── entity/Practice.java                  → add faxNumber field + getter/setter
├── dto/PracticeDTO.java                  → add faxNumber field (already has @Data via Lombok)
└── resource/contract/PracticeContract.java → update @PreAuthorize to hasAnyAuthority
```

> `IPracticeRepository`, `PracticeRepository`, `IPracticeService`, `PracticeServiceImpl`, and `PracticeController` require **no changes** — the existing generic query-param passthrough already supports `primaryMinistry`.

---

## 8. Testing Requirements

| Test | Type | File |
|---|---|---|
| `faxNumber` persists and is returned | Unit | `PracticeServiceImplTest` |
| `GET /practices?primaryMinistry=TXAUS` returns `200` with matching data | Unit | `PracticeControllerTest` |
| `GET /practices?primaryMinistry=UNKNOWN` returns `204` on no match | Unit | `PracticeControllerTest` |
| `GET /practices?primaryMinistry=TXAUS` with `surgery_schedule.read` scope returns `200` | Unit | `PracticeControllerTest` |
| `GET /practices?primaryMinistry=TXAUS` with no valid scope returns `403` | Unit | `PracticeControllerTest` |
| End-to-end ministry lookup with `faxNumber` populated | Integration | `PracticeControllerIT` |

---

## 9. Definition of Done

- [ ] `faxNumber` field added to `entity/Practice.java` and `procedure/dto/PracticeDTO.java`
- [ ] `@PreAuthorize` on `getAllPractice` updated to `hasAnyAuthority` with both scopes
- [ ] All 7 acceptance criteria pass
- [ ] Unit tests added/updated with no regression
- [ ] OpenAPI docs updated (auto-generated via `PracticeContract` annotations)
- [ ] Code reviewed and merged to the feature branch
- [ ] Deployed to QA and validated: `GET /practices?primaryMinistry=<ministry>` returns practices with `faxNumber`
