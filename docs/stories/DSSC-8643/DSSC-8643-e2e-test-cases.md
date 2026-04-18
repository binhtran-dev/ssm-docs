# Manual E2E Test Cases: DSSC-8643

**Feature:** Practice `faxNumber` field & `primaryMinistry` filter
**Service:** `mit-surgical`
**Base URL:** `https://<env>.example.com` (replace with target environment)
**Prerequisites:**
- Valid OAuth2 Bearer token with `SCOPE_dssc_schedule_app.practice.read` (referred to as **practice-read token**)
- Valid OAuth2 Bearer token with `SCOPE_dssc_schedule_app.surgery_schedule.read` only (referred to as **surgery-read token**)
- Valid OAuth2 Bearer token with neither scope (referred to as **no-scope token**)
- Access to MongoDB (`casetracker` database, `practice` collection)

---

## Test Data Setup

Before running tests, insert test documents directly in MongoDB:

```javascript
// Practice WITH faxNumber and primaryMinistry
db.practice.insertOne({
  name: "E2E Test Practice - With Fax",
  address: "100 Test Ave",
  city: "Austin",
  state: "TX",
  zipCode: "78701",
  euid: "E2E-FAX-001",
  primaryMinistry: "TXAUS",
  primaryHospital: "Dell Children's Medical Center",
  faxNumber: "+15125550101",
  surgeons: []
})

// Practice WITHOUT faxNumber, same ministry
db.practice.insertOne({
  name: "E2E Test Practice - No Fax",
  address: "200 Test Blvd",
  city: "Austin",
  state: "TX",
  zipCode: "78702",
  euid: "E2E-FAX-002",
  primaryMinistry: "TXAUS",
  primaryHospital: "Ascension Seton Medical Center",
  surgeons: []
})

// Practice in a different ministry
db.practice.insertOne({
  name: "E2E Test Practice - Other Ministry",
  address: "300 Test St",
  city: "Jacksonville",
  state: "FL",
  zipCode: "32216",
  euid: "E2E-FAX-003",
  primaryMinistry: "FLJAX",
  primaryHospital: "Ascension St. Vincent's",
  faxNumber: "+19045550202",
  surgeons: []
})
```

Record the `_id` values returned for use in individual test cases.

---

## TC-01: `faxNumber` returned when retrieving practice by ID

| Field | Value |
|---|---|
| **Covers** | AC-1, AC-4 |
| **Priority** | High |

**Steps:**
1. Copy the `_id` of "E2E Test Practice - With Fax" (inserted above).
2. Send request:
   ```
   GET /practices/{id}
   Authorization: Bearer <practice-read token>
   ```
3. Inspect the response body.

**Expected Result:**
- Status: `200 OK`
- Response contains `"faxNumber": "+15125550101"`
- All other existing fields (`name`, `address`, `primaryMinistry`, etc.) are present and correct.

---

## TC-02: `faxNumber` is null for practice without one

| Field | Value |
|---|---|
| **Covers** | AC-2 |
| **Priority** | High |

**Steps:**
1. Copy the `_id` of "E2E Test Practice - No Fax".
2. Send request:
   ```
   GET /practices/{id}
   Authorization: Bearer <practice-read token>
   ```
3. Inspect the response body.

**Expected Result:**
- Status: `200 OK`
- `faxNumber` is `null` or absent in the response.
- No error is thrown.

---

## TC-03: Filter practices by `primaryMinistry`

| Field | Value |
|---|---|
| **Covers** | AC-3, AC-4 |
| **Priority** | High |

**Steps:**
1. Send request:
   ```
   GET /practices?primaryMinistry=TXAUS
   Authorization: Bearer <practice-read token>
   ```
2. Inspect the response body.

**Expected Result:**
- Status: `200 OK`
- Response is a JSON array.
- Every practice in the array has `"primaryMinistry": "TXAUS"`.
- "E2E Test Practice - With Fax" and "E2E Test Practice - No Fax" are present.
- "E2E Test Practice - Other Ministry" (FLJAX) is **not** in the response.
- The practice with fax includes `"faxNumber": "+15125550101"`.

---

## TC-04: Filter by `primaryMinistry` with no matches returns 204

| Field | Value |
|---|---|
| **Covers** | AC-5 |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /practices?primaryMinistry=NONEXISTENT
   Authorization: Bearer <practice-read token>
   ```

**Expected Result:**
- Status: `204 No Content`
- Response body is empty.

---

## TC-05: Access with `surgery_schedule.read` scope only

| Field | Value |
|---|---|
| **Covers** | AC-3 (scope expansion) |
| **Priority** | High |

**Steps:**
1. Obtain a token that has `SCOPE_dssc_schedule_app.surgery_schedule.read` but **not** `SCOPE_dssc_schedule_app.practice.read`.
2. Send request:
   ```
   GET /practices?primaryMinistry=TXAUS
   Authorization: Bearer <surgery-read token>
   ```

**Expected Result:**
- Status: `200 OK` (not `403`)
- Response contains practices filtered by `TXAUS`.

---

## TC-06: Access denied without required scope

| Field | Value |
|---|---|
| **Covers** | AC-7 |
| **Priority** | High |

**Steps:**
1. Obtain a token that has **neither** `practice.read` nor `surgery_schedule.read`.
2. Send request:
   ```
   GET /practices?primaryMinistry=TXAUS
   Authorization: Bearer <no-scope token>
   ```

**Expected Result:**
- Status: `403 Forbidden`
- Response body contains an error message (AscensionFault).

---

## TC-07: Unauthenticated request returns 401

| Field | Value |
|---|---|
| **Covers** | AC-6 |
| **Priority** | High |

**Steps:**
1. Send request **without** an `Authorization` header:
   ```
   GET /practices?primaryMinistry=TXAUS
   ```

**Expected Result:**
- Status: `401 Unauthorized`

---

## TC-08: `faxNumber` returned in unfiltered practice list

| Field | Value |
|---|---|
| **Covers** | AC-1 |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /practices
   Authorization: Bearer <practice-read token>
   ```
2. Find "E2E Test Practice - With Fax" in the response array.

**Expected Result:**
- Status: `200 OK`
- The practice with `euid: "E2E-FAX-001"` includes `"faxNumber": "+15125550101"`.
- The practice with `euid: "E2E-FAX-002"` has `faxNumber` as `null` or absent.

---

## TC-09: Retrieve practice by EUID includes `faxNumber`

| Field | Value |
|---|---|
| **Covers** | AC-1 |
| **Priority** | Medium |

**Steps:**
1. Send request:
   ```
   GET /practices/E2E-FAX-001
   Authorization: Bearer <practice-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- Response contains `"faxNumber": "+15125550101"` and `"euid": "E2E-FAX-001"`.

---

## TC-10: Combined filter — `primaryMinistry` with other query params

| Field | Value |
|---|---|
| **Covers** | AC-3 (generic param passthrough) |
| **Priority** | Low |

**Steps:**
1. Send request:
   ```
   GET /practices?primaryMinistry=TXAUS&state=TX
   Authorization: Bearer <practice-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- All returned practices have both `"primaryMinistry": "TXAUS"` and `"state": "TX"`.

---

## TC-11: Existing pre-DSSC-8643 practices return null faxNumber

| Field | Value |
|---|---|
| **Covers** | AC-2 (backward compatibility) |
| **Priority** | Medium |

**Steps:**
1. Query a practice that existed **before** the DSSC-8643 deployment (one that was never updated with `faxNumber`).
   ```
   GET /practices/{existing-practice-id}
   Authorization: Bearer <practice-read token>
   ```

**Expected Result:**
- Status: `200 OK`
- `faxNumber` is `null` or absent — no errors, no breaking changes.

---

## Test Data Cleanup

After testing, remove the test documents:

```javascript
db.practice.deleteMany({ euid: { $in: ["E2E-FAX-001", "E2E-FAX-002", "E2E-FAX-003"] } })
```

---

## Summary

| Test Case | Acceptance Criteria | Priority | Pass / Fail |
|---|---|---|---|
| TC-01: faxNumber returned by ID | AC-1, AC-4 | High | |
| TC-02: faxNumber null when absent | AC-2 | High | |
| TC-03: Filter by primaryMinistry | AC-3, AC-4 | High | |
| TC-04: No match returns 204 | AC-5 | Medium | |
| TC-05: surgery_schedule.read scope grants access | AC-3 | High | |
| TC-06: No scope returns 403 | AC-7 | High | |
| TC-07: No auth returns 401 | AC-6 | High | |
| TC-08: faxNumber in unfiltered list | AC-1 | Medium | |
| TC-09: faxNumber by EUID lookup | AC-1 | Medium | |
| TC-10: Combined query params | AC-3 | Low | |
| TC-11: Backward compat — old practices | AC-2 | Medium | |
