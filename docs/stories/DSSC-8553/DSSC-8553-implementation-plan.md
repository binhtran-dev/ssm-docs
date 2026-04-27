# Implementation Plan: DSSC-8553
# SSM API - Update Unit Endpoint to Include Facility Fax Number

**Branch:** `feature/DSSC-8553-unit-fax-number`
**Estimated effort:** 5 files changed (no new files), ~80-110 lines updated

---

## Step 1 - Reuse Existing ScheduleConfig

**File:** `src/main/java/org/ascension/swe/surgical/procedure/entity/ScheduleConfig.java`

Do not create a new `ScheduleConfig` file. Reuse the existing class as-is unless a concrete gap is found.

---

## Step 2 - `entity/Unit.java` (faxNumber only)

**File:** `src/main/java/org/ascension/swe/surgical/procedure/entity/Unit.java`

Add only:

```java
private String faxNumber;
```

Update `toString()` to include `faxNumber`.

Keep existing model behavior unchanged:

1. Keep primitive booleans (no `Boolean` wrapper migration).
2. Keep enum-backed entity collections:
   - `List<RequestTypeEnum> requestTypes`
   - `List<CalendarTypeEnum> calendarTypes`
3. No entity conversion to `List<String>`.

---

## Step 3 - `dto/UnitDTO.java` (minimal)

**File:** `src/main/java/org/ascension/swe/surgical/procedure/dto/UnitDTO.java`

Add `faxNumber` only if missing:

```java
private String faxNumber;
```

Already implemented in DTO and out of scope for new changes:

1. `ministry`
2. `hospitalCernerId`

Compatibility rules:

1. Keep current boolean semantics (treat null-like values as false where applicable).
2. Keep existing `requestTypes` / `calendarTypes` behavior unchanged.

---

## Step 4 - `repository/impl/HospitalRepository.java` (minimal projection change)

**File:** `src/main/java/org/ascension/swe/surgical/procedure/repository/impl/HospitalRepository.java`

In `findAllUnitsByHospitalIds()`:

1. Add `faxNumber` to the existing `Aggregation.project(...)` fields from the `Unit` document.
2. Keep current `hospitalData` mappings (`ministry`, `market`, `ministryLocation`, `hospitalTimeZone`, `hospitalCernerId`).
3. Do not map `hospitalData.faxNumber` because Hospital currently has no `faxNumber` field.

No full projection rewrite.

---

## Step 5 - Update Tests

### 5.1 Repository and Service Unit Tests

**Files:**

1. `src/test/unit/java/org/ascension/swe/surgical/procedure/repository/impl/HospitalRepositoryTest.java`
2. `src/test/unit/java/org/ascension/swe/surgical/procedure/service/impl/HospitalServiceImplTest.java`

Update fixtures/assertions to:

1. Include and assert `faxNumber` in relevant Unit/UnitDTO objects.
2. Do not set primitive booleans to `null`.
3. Keep enum-based behavior for entity request/calendar types.

### 5.2 Controller Contract Tests

**Files:**

1. `src/test/unit/java/org/ascension/swe/surgical/procedure/resource/HospitalControllerTest.java`
2. `src/test/integration/java/org/ascension/swe/surgical/procedure/resource/HospitalControllerIT.java`

Add assertions that `GET /hospital/user/units/` includes `faxNumber` and does not regress existing payload fields.

---

## Step 6 - Data Backfill

Because `faxNumber` is added to `Unit`, backfill existing Unit documents as needed before QA verification.

Validation target: units returned by `GET /hospital/user/units/` include expected `faxNumber` values.

---

## Step 7 - Verify Build

```bash
cd /Users/binhtran/work/projects/ssm/mit-surgical
mvn clean test -pl . -Dtest="UnitDTOTest,UnitRepositoryTest,HospitalRepositoryTest,HospitalServiceImplTest,HospitalControllerTest,HospitalControllerIT" -DfailIfNoTests=false
```

All listed test classes must pass with no regression failures.

---

## Step 8 - Post-Deployment (QA Environment)

After QA deployment, flush `SURGERY_REQUEST_HOSPITAL_UNITDTOS` cache entries so `GET /hospital/user/units/` returns refreshed projections including `faxNumber`.

**Redis CLI command (run against the QA Redis instance):**

```bash
redis-cli -h <qa-redis-host> -p 6379 KEYS "SURGERY_REQUEST_HOSPITAL_UNITDTOS*" | xargs redis-cli -h <qa-redis-host> -p 6379 DEL
```

Or via the Spring Actuator cache endpoint if enabled:

```bash
curl -X DELETE https://<qa-host>/actuator/caches/SURGERY_REQUEST_HOSPITAL_UNITDTOS
```

---

## Summary

| # | File | Change |
|---|---|---|
| 1 | `entity/Unit.java` | Add `faxNumber`; update `toString()` |
| 2 | `dto/UnitDTO.java` | Add `faxNumber` only if missing |
| 3 | `repository/impl/HospitalRepository.java` | Add `faxNumber` to existing Unit projection |
| 4 | `HospitalRepositoryTest.java` | Add `faxNumber` fixture/assertions; keep primitive/enum semantics |
| 5 | `HospitalServiceImplTest.java` | Add `faxNumber` fixture/assertions; no null primitive assignments |
| 6 | `HospitalControllerTest.java` | Assert `faxNumber` in units response |
| 7 | `HospitalControllerIT.java` | Assert `faxNumber` in endpoint contract |

**Production files changed: 3**
**Test files changed: 4**
**No new files**
