# Manual E2E Test Cases: DSSC-8672

Feature: User Profile Detail faxNumber fields
Service: mit-surgical
Endpoint: GET /user/profile/detail
Base URL: https://<env>.example.com (replace with target environment)

Prerequisites:
- Valid OAuth2 Bearer token with SCOPE_USER_PROFILE_READ for an Office Scheduler user (office token)
- Valid OAuth2 Bearer token with SCOPE_USER_PROFILE_READ for an OR Scheduler user (or token)
- Valid OAuth2 Bearer token without SCOPE_USER_PROFILE_READ (wrong-scope token)
- No-token request capability for unauthenticated test
- Access to source data stores/services used by profile detail mapping (user profile + practice/unit source data)

---

## Test Data Setup

Prepare users and source entities so expected values are deterministic.

Recommended setup:
1. Office scheduler test user:
- Has at least one primary practice and at least one practice in preference.practices
- At least one linked practice has faxNumber = "555-555-1111"
- At least one linked practice has faxNumber = null (or missing)

2. OR scheduler test user:
- Has at least one primary hospital with units and at least one hospital in preference.hospitals with units
- At least one linked unit has faxNumber = "512-123-1234"
- At least one linked unit has faxNumber = null (or missing)

3. Keep note of:
- Office scheduler identity used for token
- OR scheduler identity used for token
- Practice IDs and Unit IDs linked to those users

If your environment requires explicit DB seeding, use your existing fixture/seeding workflow and ensure linked practice/unit records include both non-null and null faxNumber values.

---

## TC-01: Office scheduler primaryPractice includes faxNumber

| Field | Value |
|---|---|
| Covers | AC-1 |
| Priority | High |

Steps:
1. Authenticate as office scheduler with office token.
2. Send request:
   GET /user/profile/detail
   Authorization: Bearer <office token>
3. Inspect response.primaryPractice.

Expected Result:
- Status: 200 OK
- response.primaryPractice exists when primary practice is configured for that user.
- response.primaryPractice.faxNumber is present and matches linked source practice data (for seeded non-null case, "555-555-1111").

---

## TC-02: Office scheduler preference.practices[] includes faxNumber

| Field | Value |
|---|---|
| Covers | AC-2 |
| Priority | High |

Steps:
1. Authenticate as office scheduler with office token.
2. Send request:
   GET /user/profile/detail
   Authorization: Bearer <office token>
3. Inspect response.preference.practices[].

Expected Result:
- Status: 200 OK
- response.preference.practices is returned.
- Each practice object includes the faxNumber field in contract (value may be null depending on source data).
- For the seeded practice with fax, faxNumber equals "555-555-1111".

---

## TC-03: OR scheduler primaryHospital.units[] includes faxNumber

| Field | Value |
|---|---|
| Covers | AC-3 |
| Priority | High |

Steps:
1. Authenticate as OR scheduler with or token.
2. Send request:
   GET /user/profile/detail
   Authorization: Bearer <or token>
3. If response.primaryHospital exists, inspect response.primaryHospital.units[].

Expected Result:
- Status: 200 OK
- When primaryHospital and units are present, each unit includes faxNumber.
- For seeded non-null unit, faxNumber equals "512-123-1234".

Note:
- Some fixtures may not mark a primary hospital. In that case, validate TC-04 as the authoritative OR-path assertion.

---

## TC-04: OR scheduler preference.hospitals[].units[] includes faxNumber

| Field | Value |
|---|---|
| Covers | AC-4 |
| Priority | High |

Steps:
1. Authenticate as OR scheduler with or token.
2. Send request:
   GET /user/profile/detail
   Authorization: Bearer <or token>
3. Inspect response.preference.hospitals[].units[].

Expected Result:
- Status: 200 OK
- response.preference.hospitals is returned.
- Each unit object includes faxNumber field in contract (value may be null depending on source data).
- For seeded non-null unit, faxNumber equals "512-123-1234".

---

## TC-05: Null-safe behavior when faxNumber is missing

| Field | Value |
|---|---|
| Covers | AC-5 |
| Priority | High |

Steps:
1. Use a user whose linked practice/unit includes at least one source record with faxNumber null or absent.
2. Send request:
   GET /user/profile/detail
   Authorization: Bearer <office token or or token>
3. Inspect corresponding nested practice/unit object.

Expected Result:
- Status: 200 OK
- No server error occurs.
- Missing fax source data is represented consistently with environment serializer behavior:
  - either faxNumber: null
  - or faxNumber omitted

---

## TC-06: Existing non-fax fields are unchanged

| Field | Value |
|---|---|
| Covers | AC-6 |
| Priority | High |

Steps:
1. Send request as office scheduler:
   GET /user/profile/detail
   Authorization: Bearer <office token>
2. Send request as OR scheduler:
   GET /user/profile/detail
   Authorization: Bearer <or token>
3. Compare payloads against pre-change contract examples/baseline snapshots.

Expected Result:
- Status: 200 OK for both requests.
- Existing fields remain available and unchanged in shape/semantics.
- Office path retains expected fields such as name, address, city, state, zipCode, euid, surgeons.
- OR unit path retains expected fields such as name, hospitalName, openTimeConfig, addressRequired.

---

## TC-07: Unauthorized without token

| Field | Value |
|---|---|
| Covers | Auth regression |
| Priority | High |

Steps:
1. Send request without Authorization header:
   GET /user/profile/detail

Expected Result:
- Status: 401 Unauthorized

---

## TC-08: Forbidden with wrong scope token

| Field | Value |
|---|---|
| Covers | Auth regression |
| Priority | High |

Steps:
1. Send request with wrong-scope token:
   GET /user/profile/detail
   Authorization: Bearer <wrong-scope token>

Expected Result:
- Status: 403 Forbidden
- Access denied due to missing SCOPE_USER_PROFILE_READ

---

## TC-09: Office scheduler end-to-end value spot check

| Field | Value |
|---|---|
| Covers | AC-1, AC-2 |
| Priority | Medium |

Steps:
1. Authenticate as office scheduler.
2. Call GET /user/profile/detail.
3. Validate at least one known practice by ID from test setup.

Expected Result:
- Known practice appears in response (primaryPractice or preference.practices[]).
- faxNumber equals seeded expected value for that practice.

---

## TC-10: OR scheduler end-to-end value spot check

| Field | Value |
|---|---|
| Covers | AC-3, AC-4 |
| Priority | Medium |

Steps:
1. Authenticate as OR scheduler.
2. Call GET /user/profile/detail.
3. Validate at least one known unit by ID from test setup.

Expected Result:
- Known unit appears in response (primaryHospital.units[] or preference.hospitals[].units[]).
- faxNumber equals seeded expected value for that unit.

---

## Optional Evidence Capture

For each test case, capture:
- Request URL and headers (redact token)
- HTTP status code
- Response snippet proving faxNumber behavior
- Timestamp and environment

---

## Test Data Cleanup

Use your environment-specific fixture cleanup process to remove/restore any temporary test faxNumber values and scheduler-user links created for this test run.

---

## Summary

| Test Case | Acceptance Criteria / Area | Priority | Pass / Fail |
|---|---|---|---|
| TC-01: Office primaryPractice faxNumber | AC-1 | High | |
| TC-02: Office preference practices faxNumber | AC-2 | High | |
| TC-03: OR primary hospital units faxNumber | AC-3 | High | |
| TC-04: OR preference hospitals units faxNumber | AC-4 | High | |
| TC-05: Null-safe fax behavior | AC-5 | High | |
| TC-06: No regression existing fields | AC-6 | High | |
| TC-07: No token returns 401 | Auth regression | High | |
| TC-08: Wrong scope returns 403 | Auth regression | High | |
| TC-09: Office value spot check | AC-1, AC-2 | Medium | |
| TC-10: OR value spot check | AC-3, AC-4 | Medium | |