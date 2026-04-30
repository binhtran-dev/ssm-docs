# Manual E2E Test Cases: DSSC-8553

**Feature:** Unit `faxNumber` field endpoint integration
**Service:** `mit-surgical`
**Base URL:** `https://<env>.example.com` (replace with target environment)
**Prerequisites:**
- Valid OAuth2 Bearer token with `SCOPE_dssc_schedule_app.surgery_request.read` scope (referred to as **request-read token**)
- Valid OAuth2 Bearer token with neither required scope (referred to as **no-scope token**)
- Access to MongoDB (`casetracker` database, `hospital` and `unit` collections)
- DSSC_OR_SCHEDULER user profile configured in test environment

---

## Test Data Setup

Before running tests, insert/update test documents directly in MongoDB:

```javascript
// Insert test hospital
db.hospital.insertOne({
  name: "E2E Test Hospital - Unit Fax",
  address: "500 Unit Ave",
  city: "Austin",
  state: "TX",
  zipCode: "78703",
  market: "TEXAS",
  ministry: "TXAUS",
  ministryLocation: "Austin, TX",
  timeZone: "America/Chicago",
  cernerId: "W1-E2E-001",
  releaseThreshold: 14
})

// Insert test unit WITH faxNumber and ScheduleConfig
db.unit.insertOne({
  name: "E2E Test Unit - With Fax",
  hospital: ObjectId("<hospital-id-from-above>"),
  hospitalName: "E2E Test Hospital - Unit Fax",
  status: "ACTIVE",
  officeOpenTimeDisabled: false,
  addressRequired: true,
  partialReleaseEnabled: true,
  disableScheduling: false,
  faxNumber: "+15125550301",
  scheduleConfig: {
    dow: [1, 2, 3, 4, 5],
    start: "7:00",
    end: "24:00",
    interval: 15
  },
  requestTypes: ["WEB_FORM_V1", "MOBILE_APP"],
  calendarTypes: ["BLOCK", "OPEN"]
})

// Insert test unit WITHOUT faxNumber, same hospital
db.unit.insertOne({
  name: "E2E Test Unit - No Fax",
  hospital: ObjectId("<hospital-id-from-above>"),
  hospitalName: "E2E Test Hospital - Unit Fax",
  status: "ACTIVE",
  officeOpenTimeDisabled: false,
  addressRequired: false,
  partialReleaseEnabled: false,
  disableScheduling: false,
  requestTypes: ["WEB_FORM_V1"],
  calendarTypes: ["BLOCK"]
})

// Insert test unit WITH faxNumber but WITHOUT ScheduleConfig
db.unit.insertOne({
  name: "E2E Test Unit - Fax No Config",
  hospital: ObjectId("<hospital-id-from-above>"),
  hospitalName: "E2E Test Hospital - Unit Fax",
  status: "ACTIVE",
  officeOpenTimeDisabled: false,
  addressRequired: true,
  partialReleaseEnabled: true,
  disableScheduling: false,
  faxNumber: "+15125550302",
  requestTypes: ["WEB_FORM_V1"],
  calendarTypes: ["BLOCK"]
})

// Insert DEACTIVATED unit (should NOT be returned by aggregation)
db.unit.insertOne({
  name: "E2E Test Unit - Deactivated",
  hospital: ObjectId("<hospital-id-from-above>"),
  hospitalName: "E2E Test Hospital - Unit Fax",
  status: "DEACTIVATED",
  faxNumber: "+15125550399",
  requestTypes: ["WEB_FORM_V1"],
  calendarTypes: ["BLOCK"]
})
```

Record the unit `_id` values (especially "E2E Test Unit - With Fax" and "E2E Test Unit - No Fax") for use in individual test cases.

---

## TC-01: `faxNumber` returned when retrieving unit by ID

| Field | Value |
|---|---|
| **Covers** | AC-1 (faxNumber included in Unit response) |
| **Priority** | High |

**Steps:**
1. Copy the `_id` of "E2E Test Unit - With Fax".
2. Send request:
   ```
   GET /hospital/unit/{unit-id}
   Authorization: Bearer <request-read token>
   ```
3. Inspect the response body.

**Expected Result:**
- Status: `200 OK`
- Response contains `"faxNumber": "+15125550301"`
- All other fields (`name`, `hospital`, `status`, `scheduleConfig`, `requestTypes`, `calendarTypes`) are present and correct.

---

## TC-02: `faxNumber` is null for unit without one

| Field | Value |
|---|---|
| **Covers** | AC-2 (backward compatibility for units without faxNumber) |
| **Priority** | High |

**Steps:**
1. Copy the `_id` of "E2E Test Unit - No Fax".
2. Send request:
   ```
   GET /hospital/unit/{unit-id}
   Authorization: Bearer <request-read token>
   ```
3. Inspect the response body.

**Expected Result:**
- Status: `200 OK`
- `faxNumber` is `null` or absent in the response.
- No error is thrown; endpoint functions normally.

---

## TC-03: `faxNumber` included in user profile units list

| Field | Value |
|---|---|
| **Covers** | AC-1, AC-4 (faxNumber in aggregation projection) |
| **Priority** | High |

**Steps:**
1. As DSSC_OR_SCHEDULER user, send request:
   ```
   GET /hospital/user/unit/
   Authorization: Bearer <request-read token>
   ```
2. Inspect the response array and find units from the test hospital.

**Expected Result:**
- Status: `200 OK`
- Response is a JSON array.
- "E2E Test Unit - With Fax" appears in the array with `"faxNumber": "+15125550301"`.
- "E2E Test Unit - No Fax" appears with `faxNumber` as `null` or absent.
- "E2E Test Unit - Fax No Config" appears with `"faxNumber": "+15125550302"`.
- All units include `hospitalTimeZone`, `hospitalCernerId`, `ministry` fields from the aggregation.

---

## TC-04: DEACTIVATED units are excluded from user profile list

| Field | Value |
|---|---|
| **Covers** | AC-5 (ACTIVE status filter in aggregation) |
| **Priority** | Medium |

**Steps:**
1. As DSSC_OR_SCHEDULER user, send request:
   ```
   GET /hospital/user/unit/
   Authorization: Bearer <request-read token>
   ```
2. Search the response array for the deactivated unit.

**Expected Result:**
- Status: `200 OK`
- "E2E Test Unit - Deactivated" is **not** in the response array.
- Only ACTIVE units are returned.

---

## TC-05: `faxNumber` returned in all units list (no filter)

| Field | Value |
|---|---|
| **Covers** | AC-1 |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /hospital/unit
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- All ACTIVE units include the `faxNumber` field (with value or `null`).
- "E2E Test Unit - With Fax" includes `"faxNumber": "+15125550301"`.

---

## TC-06: Unit by name includes `faxNumber`

| Field | Value |
|---|---|
| **Covers** | AC-1 (faxNumber consistency across retrieval methods) |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /hospital/unit?name=E2E Test Unit - With Fax
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- Response contains `"faxNumber": "+15125550301"` and `"name": "E2E Test Unit - With Fax"`.
- `hospitalTimeZone`, `hospitalCernerId`, `ministry` are populated from hospital data.

---

## TC-07: `faxNumber` persists with ScheduleConfig

| Field | Value |
|---|---|
| **Covers** | AC-1, AC-3 (faxNumber orthogonal to existing fields) |
| **Priority** | High |

**Steps:**
1. Copy the `_id` of "E2E Test Unit - With Fax".
2. Send request:
   ```
   GET /hospital/unit/{unit-id}
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- Response contains both:
  - `"faxNumber": "+15125550301"`
  - `"scheduleConfig"` with `dow`, `start`, `end`, `interval` intact.
- ScheduleConfig values are unchanged.

---

## TC-08: `faxNumber` returned without ScheduleConfig

| Field | Value |
|---|---|
| **Covers** | AC-1 (faxNumber independent of config) |
| **Priority** | Medium |

**Steps:**
1. Copy the `_id` of "E2E Test Unit - Fax No Config".
2. Send request:
   ```
   GET /hospital/unit/{unit-id}
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- Response contains `"faxNumber": "+15125550302"`.
- `scheduleConfig` is `null` or absent.
- No errors thrown.

---

## TC-09: Aggregation projection includes all expected fields

| Field | Value |
|---|---|
| **Covers** | AC-4 (HospitalRepository projection updated correctly) |
| **Priority** | High |

**Steps:**
1. As DSSC_OR_SCHEDULER user, send request:
   ```
   GET /hospital/user/unit/
   Authorization: Bearer <request-read token>
   ```
2. Select the first unit from the response.

**Expected Result:**
- Status: `200 OK`
- Response unit contains all of:
  - From Unit document: `id`, `name`, `hospital`, `hospitalName`, `status`, `scheduleConfig`, `officeOpenTimeDisabled`, `addressRequired`, `disableScheduling`, `partialReleaseEnabled`, **`faxNumber`**, `requestTypes`, `calendarTypes`
  - From Hospital aggregation: `ministry`, `market`, `ministryLocation`, `hospitalTimeZone`, `hospitalCernerId`

---

## TC-10: Existing pre-DSSC-8553 units return null faxNumber

| Field | Value |
|---|---|
| **Covers** | AC-2 (backward compatibility) |
| **Priority** | High |

**Steps:**
1. Query a unit that existed **before** the DSSC-8553 deployment (one that was never updated with `faxNumber`).
   ```
   GET /hospital/unit/{existing-unit-id}
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- `faxNumber` is `null` or absent — no errors, no breaking changes.
- All other existing fields function normally.

---

## TC-11: Cache invalidation includes faxNumber updates

| Field | Value |
|---|---|
| **Covers** | AC-6 (post-deployment cache flush) |
| **Priority** | Medium |

**Steps:**
1. Retrieve the user profile units before cache flush:
   ```
   GET /hospital/user/unit/
   Authorization: Bearer <request-read token>
   ```
   Record the response.
2. Update a unit's `faxNumber` in MongoDB:
   ```javascript
   db.unit.updateOne(
     { name: "E2E Test Unit - No Fax" },
     { $set: { faxNumber: "+15125550350" } }
   )
   ```
3. Retrieve user profile units again **without** flushing cache.
4. Flush the cache:
   ```bash
   redis-cli -h <qa-redis-host> -p 6379 KEYS "SURGERY_REQUEST_HOSPITAL_UNITDTOS*" | xargs redis-cli -h <qa-redis-host> -p 6379 DEL
   ```
   Or via actuator:
   ```bash
   curl -X DELETE https://<qa-host>/actuator/caches/SURGERY_REQUEST_HOSPITAL_UNITDTOS
   ```
5. Retrieve user profile units again **after** cache flush.

**Expected Result:**
- Before cache flush: `faxNumber` is `null` or absent (original value).
- After cache flush: `faxNumber` is `"+15125550350"` (updated value).
- Cache invalidation correctly applies to the aggregation.

---

## TC-12: UnitDTO serialization includes faxNumber

| Field | Value |
|---|---|
| **Covers** | AC-1 (UnitDTO field properly exported) |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /hospital/unit/{unit-with-fax-id}
   Authorization: Bearer <request-read token>
   Content-Type: application/json
   ```
2. Parse the response JSON.

**Expected Result:**
- Status: `200 OK`
- JSON payload includes `"faxNumber"` key.
- OpenAPI schema for UnitDTO reflects `faxNumber` field with description "Facility fax number associated with the unit".
- No JSON serialization errors.

---

## TC-13: Unauthenticated request returns 401

| Field | Value |
|---|---|
| **Covers** | Security (auth required) |
| **Priority** | High |

**Steps:**
1. Send request **without** an `Authorization` header:
   ```
   GET /hospital/user/unit/
   ```

**Expected Result:**
- Status: `401 Unauthorized`

---

## TC-14: Insufficient scope returns 403

| Field | Value |
|---|---|
| **Covers** | Security (scope enforcement) |
| **Priority** | High |

**Steps:**
1. Obtain a token with **no** relevant scope.
2. Send request:
   ```
   GET /hospital/user/unit/
   Authorization: Bearer <no-scope token>
   ```

**Expected Result:**
- Status: `403 Forbidden`
- Response body contains an error message.

---

## TC-15: Malformed unit ID returns 404

| Field | Value |
|---|---|
| **Covers** | Error handling |
| **Priority** | Medium |

**Steps:**
1. Send request with invalid ObjectId:
   ```
   GET /hospital/unit/invalid-id-format
   Authorization: Bearer <request-read token>
   ```

**Expected Result:**
- Status: `400 Bad Request` or `404 Not Found` (depending on implementation).
- Response body contains an error message.

---

## Test Data Cleanup

After testing, remove the test documents:

```javascript
db.unit.deleteMany({ 
  name: { $in: [
    "E2E Test Unit - With Fax",
    "E2E Test Unit - No Fax",
    "E2E Test Unit - Fax No Config",
    "E2E Test Unit - Deactivated"
  ] }
})

db.hospital.deleteOne({ name: "E2E Test Hospital - Unit Fax" })
```

---

## Summary

| Test Case | Acceptance Criteria | Priority | Pass / Fail |
|---|---|---|---|
| TC-01: faxNumber returned by ID | AC-1, AC-2 | High | |
| TC-02: faxNumber null when absent | AC-2 | High | |
| TC-03: faxNumber in user profile units | AC-1, AC-4 | High | |
| TC-04: DEACTIVATED units excluded | AC-5 | Medium | |
| TC-05: faxNumber in all units list | AC-1 | Medium | |
| TC-06: faxNumber by name lookup | AC-1 | Medium | |
| TC-07: faxNumber with ScheduleConfig | AC-1, AC-3 | High | |
| TC-08: faxNumber without ScheduleConfig | AC-1 | Medium | |
| TC-09: Aggregation projection complete | AC-4 | High | |
| TC-10: Backward compat — old units | AC-2 | High | |
| TC-11: Cache invalidation for faxNumber | AC-6 | Medium | |
| TC-12: UnitDTO serialization | AC-1 | Medium | |
| TC-13: Unauthenticated returns 401 | Security | High | |
| TC-14: Insufficient scope returns 403 | Security | High | |
| TC-15: Malformed ID error handling | Error Handling | Medium | |

---

## Notes

- All test cases assume the DSSC_OR_SCHEDULER user profile is properly configured with access to the test hospital and units.
- Test data setup uses MongoDB directly; ensure your test environment has MongoDB access.
- Cache cleanup (TC-11) is critical for QA verification; coordinate with DevOps for Redis access.
- UnitDTO `@Schema` annotation includes `faxNumber` with description: *"Facility fax number associated with the unit"* and example *"512-555-1234"*.
- Backward compatibility (TC-10) ensures no breaking changes for units created before DSSC-8553 deployment.
