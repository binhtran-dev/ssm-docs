# Implementation Plan: DSSC-8553
# SSM API — Update Unit Endpoint to Include Facility Fax Number

**Branch:** `feature/DSSC-8553-unit-fax-number`
**Estimated effort:** 4 files changed (1 new), ~120 lines added

---

## Step 1 — New file: `entity/ScheduleConfig.java`

**File:** `src/main/java/org/ascension/swe/surgical/procedure/entity/ScheduleConfig.java`

Create a plain `Serializable` value class with `start` and `end` `String` fields, following the existing style (no Lombok, explicit getter/setter).

```java
private String start;
private String end;
// + getters/setters
```

---

## Step 2 — `entity/Unit.java`

**File:** `src/main/java/org/ascension/swe/surgical/procedure/entity/Unit.java`

Add `import java.util.List;`. Add the following fields after `hospitalName`, with getters/setters:

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

**Update `toString()` to include `faxNumber`:**

```java
@Override
public String toString() {
    return "Unit{" +
            "id='" + id + '\'' +
            ", name='" + name + '\'' +
            ", hospital=" + hospital +
            ", hospitalName='" + hospitalName + '\'' +
            ", faxNumber='" + faxNumber + '\'' +
            '}';
}
```

---

## Step 3 — `dto/UnitDTO.java`

**File:** `src/main/java/org/ascension/swe/surgical/procedure/dto/UnitDTO.java`

Add `import java.util.List;` and `import org.ascension.swe.surgical.procedure.entity.ScheduleConfig;`. Add the following fields after `hospitalTimeZone`, with getters/setters:

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

> Note: `ministry` was already projected by the aggregation but was never declared as a DTO field — it must be added here.

---

## Step 4 — `repository/impl/HospitalRepository.java`

**File:** `src/main/java/org/ascension/swe/surgical/procedure/repository/impl/HospitalRepository.java`

In `findAllUnitsByHospitalIds()`, replace the `Aggregation.project(...)` block. All new unit fields must be listed explicitly, and `hospitalCernerId` must be joined from `hospitalData`.

**Replace:**

```java
Aggregation.project("id", "name", HOSPITAL, "hospitalName")
        .and("hospitalData.ministry").as(MINISTRY)
        .and("hospitalData.market").as(MARKET)
        .and("hospitalData.ministryLocation").as(MINISTRY_LOCATION)
        .and("hospitalData.timeZone").as("hospitalTimeZone")
```

**With:**

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

No other changes to this file.

---

## Step 5 — Update Existing Tests

No new test classes needed. Update the `setUp()` data in two existing test files so that assertions using `ModelHelper.writeValueAsString()` remain consistent with the expanded DTO shape.

### 5.1 `HospitalRepositoryTest.java`

**File:** `src/test/unit/java/org/ascension/swe/surgical/procedure/repository/impl/HospitalRepositoryTest.java`

In `setUp()`, after `unitDTO.setHospitalTimeZone(...)`, set the new fields on the test `unitDTO` to match expected aggregation output. At minimum:

```java
unitDTO.setFaxNumber("5121234567");
unitDTO.setHospitalCernerId("W1-592210");
unitDTO.setOpenTimeConfig(true);
unitDTO.setPartialReleaseEnabled(true);
unitDTO.setDisableScheduling(false);
unitDTO.setRequestTypes(List.of("WEB_FORM_ATTACHMENT"));
unitDTO.setCalendarTypes(List.of("BLOCK"));
unitDTO.setOfficeOpenTimeDisabled(false);
unitDTO.setAddressRequired(false);
```

Update any string equality assertions on the serialized DTO accordingly.

### 5.2 `HospitalServiceImplTest.java`

**File:** `src/test/unit/java/org/ascension/swe/surgical/procedure/service/impl/HospitalServiceImplTest.java`

In `setUp()`, set all new `Unit` fields to `null` on `unit1`, `unit2`, `unit3` to keep objects explicitly null-safe:

```java
unit1.setFaxNumber(null);
unit1.setOpenTimeConfig(null);
unit1.setScheduleConfig(null);
// repeat for unit2, unit3
```

---

## Step 6 — Verify Build

```bash
cd /Users/binhtran/work/projects/ssm/mit-surgical
mvn clean test -pl . -Dtest="UnitDTOTest,UnitRepositoryTest,HospitalRepositoryTest,HospitalServiceImplTest" -DfailIfNoTests=false
```

All 4 test classes must pass. No new test failures should be introduced.

---

## Step 7 — Post-Deployment (QA Environment)

After the service is deployed to QA, flush the Redis cache entry so that `GET /hospital/user/units/` does not serve stale projections missing `faxNumber`.

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
| 1 | `entity/ScheduleConfig.java` | **New file** — embedded value class (`start`, `end`) |
| 2 | `entity/Unit.java` | Add 9 new fields + getters/setters + update `toString()` |
| 3 | `dto/UnitDTO.java` | Add 11 new fields (`ministry`, `hospitalCernerId` + 9 unit fields) + getters/setters |
| 4 | `repository/impl/HospitalRepository.java` | Add all new fields + `hospitalCernerId` to aggregation `project()` call |
| 5 | `HospitalRepositoryTest.java` | Set all new fields on test `unitDTO` in `setUp()` |
| 6 | `HospitalServiceImplTest.java` | Set new fields to `null` on `unit1/2/3` in `setUp()` |

**Production files changed: 4 (1 new)**
**Test files changed: 2**
