# Feature Specification: DSSC-8553
# SSM API — Update Unit Endpoint to Include Facility Fax Number

**Service:** `mit-surgical`
**Epic:** Fax Management — Epic 2 (Core API & Integration) / Story 2.5 (Reuse of Units Endpoints for Queues)
**Story Type:** Backend API
**Related Spec:** [Backend Technical Specification - TXAUS Fax Management](../../../../../../Documents/Fax%20Management/Backend%20Technical%20Specification%20-%20TXAUS%20Fax%20Management.md)

---

## 1. Background & Business Context

In the Fax Management system, each OR unit (queue) has a dedicated inbound fax number. RightFax deposits files in GCS using the path:

```
/{ministry}/{receiverFaxNumber}/{senderFaxNumber}/yyyy-mm-dd/{fileName}.pdf
```

The `receiverFaxNumber` segment identifies the **destination OR unit**. For the Document Service and UI to resolve a fax to its queue (unit), and for the inbox UI to display the fax number alongside the unit name, the unit endpoint must include `faxNumber` in its response.

Currently, `faxNumber` is **not a field** in the `Unit` Java entity or `UnitDTO`, so no unit endpoint returns it.

---

## 2. Goals

Surface the full set of unit configuration fields — including `faxNumber`, `hospitalCernerId`, `openTimeConfig`, `partialReleaseEnabled`, `disableScheduling`, `requestTypes`, `calendarTypes`, `officeOpenTimeDisabled`, `scheduleConfig`, and `addressRequired` — so that all existing unit-related API endpoints return the complete unit representation provisioned in MongoDB.

---

## 3. Out of Scope

- Creating a new endpoint (no new routes needed; update existing ones).
- Changes to `dssc-document-service` or the Cloud Function.
- UI changes.
- Schema migration: MongoDB is schema-less; existing documents return `null` for unpopulated fields until updated via data provisioning.

---

## 4. Current State

### 4.1 `Unit.java` Entity (current fields)

```
id, name, hospital (ObjectId), hospitalName
```

### 4.2 `UnitDTO.java` (current fields)

```
id, name, hospital, hospitalName, hospitalTimeZone
```

> All other fields in the Jira story response (`hospitalCernerId`, `openTimeConfig`, `partialReleaseEnabled`, `disableScheduling`, `requestTypes`, `calendarTypes`, `officeOpenTimeDisabled`, `scheduleConfig`, `addressRequired`, `faxNumber`) are stored in MongoDB but not yet mapped to the Java model or returned by any endpoint.

### 4.3 Affected Endpoints

| Endpoint | Method in Service | How `Unit` is fetched | Notes |
|---|---|---|---|
| `GET /hospital/unit/` | `findAllUnits()` | `mongoTemplate.findAll(Unit.class, "unit")` | Direct entity mapping |
| `GET /hospital/user/units/` | `findAllUnitsByUserProfileMinistry()` | `hospitalRepository.findAllUnitsByHospitalIds()` | **Explicit aggregation projection** — must be updated |
| `GET /hospital/unit/{id}` | `findUnitById()` | `mongoTemplate.findById(...)` | Direct entity mapping |

---

## 5. Data Model Change

### 5.1 New fields on `Unit.java` entity

| Field | Type | Required | Indexed | Source | Notes |
|---|---|---|---|---|---|
| `openTimeConfig` | `Boolean` | No | No | `unit` collection | Whether open time configuration is enabled |
| `partialReleaseEnabled` | `Boolean` | No | No | `unit` collection | Whether partial release is enabled |
| `disableScheduling` | `Boolean` | No | No | `unit` collection | Whether scheduling is disabled |
| `requestTypes` | `List<String>` | No | No | `unit` collection | e.g. `["WEB_FORM_ATTACHMENT"]` |
| `calendarTypes` | `List<String>` | No | No | `unit` collection | e.g. `["BLOCK"]` |
| `officeOpenTimeDisabled` | `Boolean` | No | No | `unit` collection | Whether office open time is disabled |
| `scheduleConfig` | `ScheduleConfig` | No | No | `unit` collection | Embedded object with `start` and `end` time strings |
| `addressRequired` | `Boolean` | No | No | `unit` collection | Whether address is required |
| `faxNumber` | `String` | No | No | `unit` collection | Inbound fax number for this OR unit/queue. Nullable. |

### 5.2 New embedded class `ScheduleConfig`

A new value class `entity/ScheduleConfig.java` with two `String` fields: `start` and `end` (e.g. `"07:00"`, `"17:00"`).

### 5.3 New fields on `UnitDTO.java`

All nine fields from §5.1 plus `hospitalCernerId` (joined from the `hospital` collection via the existing aggregation `$lookup`):

| Field | Type | Source |
|---|---|---|
| `hospitalCernerId` | `String` | `hospitalData.cernerId` (from `$lookup`) |
| `openTimeConfig` | `Boolean` | direct from `unit` |
| `partialReleaseEnabled` | `Boolean` | direct from `unit` |
| `disableScheduling` | `Boolean` | direct from `unit` |
| `requestTypes` | `List<String>` | direct from `unit` |
| `calendarTypes` | `List<String>` | direct from `unit` |
| `officeOpenTimeDisabled` | `Boolean` | direct from `unit` |
| `scheduleConfig` | `ScheduleConfig` | direct from `unit` |
| `addressRequired` | `Boolean` | direct from `unit` |
| `faxNumber` | `String` | direct from `unit` |

**MongoDB migration:** Not required. Existing documents return `null` for any unpopulated field.

---

## 6. Code Changes

### 6.1 New file: `entity/ScheduleConfig.java`

Create a plain serializable value class with `start` and `end` `String` fields plus getters/setters.

### 6.2 `Unit.java` — add all new fields

Add the following fields with getters/setters after `hospitalName` (no Lombok; follow existing explicit style):

```java
private Boolean openTimeConfig;
private Boolean partialReleaseEnabled;
private Boolean disableScheduling;
private List<String> requestTypes;
private List<String> calendarTypes;
private Boolean officeOpenTimeDisabled;
private ScheduleConfig scheduleConfig;
private Boolean addressRequired;
private String faxNumber;
```

Add `import java.util.List;`. Update `toString()` to include `faxNumber`.

### 6.3 `UnitDTO.java` — add all new fields

Add the following fields with getters/setters after `hospitalTimeZone`:

```java
private String ministry;
private String hospitalCernerId;
private Boolean openTimeConfig;
private Boolean partialReleaseEnabled;
private Boolean disableScheduling;
private List<String> requestTypes;
private List<String> calendarTypes;
private Boolean officeOpenTimeDisabled;
private ScheduleConfig scheduleConfig;
private Boolean addressRequired;
private String faxNumber;
```

Add `import java.util.List;` and `import org.ascension.swe.surgical.procedure.entity.ScheduleConfig;`.

> Note: `ministry` was already projected via aggregation but was never declared as a DTO field. It must be added now.

### 6.4 `HospitalRepository.findAllUnitsByHospitalIds()` — update aggregation projection

The current projection explicitly lists fields. Any field not declared here is silently dropped even if present on the entity and DTO.

**Current projection:**
```java
Aggregation.project("id", "name", HOSPITAL, "hospitalName")
        .and("hospitalData.ministry").as(MINISTRY)
        .and("hospitalData.market").as(MARKET)
        .and("hospitalData.ministryLocation").as(MINISTRY_LOCATION)
        .and("hospitalData.timeZone").as("hospitalTimeZone")
```

**Updated projection:**
```java
Aggregation.project("id", "name", HOSPITAL, "hospitalName",
                "openTimeConfig", "partialReleaseEnabled", "disableScheduling",
                "requestTypes", "calendarTypes", "officeOpenTimeDisabled",
                "scheduleConfig", "addressRequired", "faxNumber")
        .and("hospitalData.ministry").as(MINISTRY)
        .and("hospitalData.market").as(MARKET)
        .and("hospitalData.ministryLocation").as(MINISTRY_LOCATION)
        .and("hospitalData.timeZone").as("hospitalTimeZone")
        .and("hospitalData.cernerId").as("hospitalCernerId")
```

### 6.5 Cache Invalidation

`findAllUnitsByHospitalIds()` is annotated `@Cacheable(cacheNames = "SURGERY_REQUEST_HOSPITAL_UNITDTOS")`. Cached entries will not include the new fields until they expire or are evicted. **After deployment, flush the `SURGERY_REQUEST_HOSPITAL_UNITDTOS` Redis cache** to ensure the updated projection takes effect immediately in all environments.

---

## 7. API Response — Target State

### `GET /hospital/unit/`, `GET /hospital/user/units/`, and `GET /hospital/unit/{id}`

```json
[
  {
    "id": "5e85e614c99ab800147ca501",
    "name": "BH CSC",
    "hospital": "5e85e614c99ab800147ca401",
    "hospitalName": "Ascension Saint Thomas Hospital Midtown",
    "hospitalTimeZone": "America/Chicago",
    "hospitalCernerId": "W1-592210",
    "openTimeConfig": true,
    "ministry": "TNNAS",
    "partialReleaseEnabled": true,
    "disableScheduling": false,
    "requestTypes": ["WEB_FORM_ATTACHMENT"],
    "calendarTypes": ["BLOCK"],
    "officeOpenTimeDisabled": false,
    "scheduleConfig": {
      "start": "07:00",
      "end": "17:00"
    },
    "addressRequired": false,
    "faxNumber": "5121234567"
  },
  {
    "id": "5e85e614c99ab800147ca502",
    "name": "BH JRI",
    "hospital": "5e85e614c99ab800147ca401",
    "hospitalName": "Ascension Saint Thomas Hospital Midtown",
    "hospitalTimeZone": "America/Chicago",
    "hospitalCernerId": "W1-592210",
    "openTimeConfig": true,
    "ministry": "TNNAS",
    "partialReleaseEnabled": true,
    "disableScheduling": false,
    "requestTypes": ["WEB_FORM_V1"],
    "calendarTypes": ["BLOCK"],
    "officeOpenTimeDisabled": false,
    "scheduleConfig": {
      "start": "07:00",
      "end": "17:00"
    },
    "addressRequired": false,
    "faxNumber": null
  }
]
```

> Units without a fax number return `faxNumber: null`. Fields not yet provisioned in MongoDB also return `null`.

---

## 8. Acceptance Criteria

### AC-1: All new unit fields returned from `GET /hospital/unit/`

**Given** a unit document in MongoDB has fields populated (e.g. `faxNumber`, `openTimeConfig`, `scheduleConfig`)  
**When** a caller with `SCOPE_dssc_schedule_app.hospital.read` sends `GET /hospital/unit/`  
**Then** the response includes all new fields with their correct values

---

### AC-2: All new unit fields returned from `GET /hospital/user/units/`

**Given** one or more units have populated fields  
**When** `GET /hospital/user/units/` is called with a valid user profile  
**Then** each `UnitDTO` in the response includes all new fields including `hospitalCernerId` (from the hospital join)

---

### AC-3: Unpopulated fields return `null` — no error thrown

**Given** a unit has no `faxNumber` (or any other new field) stored in MongoDB  
**When** any unit endpoint is called  
**Then** those fields are `null` in the response and no error is thrown

---

### AC-4: All new unit fields returned from `GET /hospital/unit/{id}`

**Given** a unit with populated new fields  
**When** `GET /hospital/unit/{id}` is called for that unit  
**Then** the response includes all new field values

---

### AC-5: No regression on existing unit fields

**Given** the existing unit response returns `id`, `name`, `hospital`, `hospitalName`, `hospitalTimeZone`  
**When** the updated endpoint is called  
**Then** all previously returned fields are still present and correct

---

### AC-6: Redis cache is cleared after deployment

**Given** the `SURGERY_REQUEST_HOSPITAL_UNITDTOS` cache may hold pre-update entries  
**When** the service is deployed to an environment  
**Then** the Redis cache key `SURGERY_REQUEST_HOSPITAL_UNITDTOS` is flushed before smoke testing

---

## 9. Files Changed Summary

```
mit-surgical/src/main/java/org/ascension/swe/surgical/procedure/
├── entity/ScheduleConfig.java                         → new embedded value class (start, end)
├── entity/Unit.java                                   → add 9 new fields + getters/setters + update toString()
├── dto/UnitDTO.java                                   → add 11 new fields + getters/setters
└── repository/impl/HospitalRepository.java            → add all new fields + hospitalCernerId to aggregation projection
```

**Total: 4 files (1 new, 3 modified)**

---

## 10. Testing Requirements

| Test | Type | File |
|---|---|---|
| All new fields present in `UnitDTO` serialization | Unit | `UnitDTOTest` |
| `findAllUnitsByHospitalIds()` projection includes all new fields + `hospitalCernerId` | Unit | `HospitalRepositoryTest` |
| `findAllUnits()` maps all new fields from entity | Unit | `HospitalServiceImplTest` |
| Unit with no new fields populated returns `null` values — no error | Unit | `HospitalServiceImplTest` |
| `GET /hospital/unit/` returns all new fields | Integration | `HospitalControllerIT` |
| `GET /hospital/user/units/` returns all new fields including `hospitalCernerId` | Integration | `HospitalControllerIT` |

---

## 11. Definition of Done

- [ ] `ScheduleConfig.java` created
- [ ] All new fields added to `Unit` entity
- [ ] All new fields (including `hospitalCernerId`) added to `UnitDTO`
- [ ] Aggregation projection in `HospitalRepository.findAllUnitsByHospitalIds()` updated to include all new fields and `hospitalCernerId`
- [ ] All 6 acceptance criteria pass
- [ ] Unit tests added/updated with no regression
- [ ] Redis cache `SURGERY_REQUEST_HOSPITAL_UNITDTOS` flushed in QA after deployment
- [ ] QA smoke test: at least one unit document in MongoDB has `faxNumber` and `scheduleConfig` set and is visible in API response
- [ ] Code reviewed and merged to feature branch

---

## 12. Open Questions

| # | Question | Owner |
|---|---|---|
| 1 | Should unpopulated fields (`faxNumber`, etc.) be returned as `null` or omitted entirely? Frontend preference needed. | FE Team |
| 2 | Who is responsible for populating new fields (e.g. `faxNumber`, `scheduleConfig`) on existing unit documents in each environment? | DevOps / Data Team |
