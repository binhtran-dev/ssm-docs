# Feature Specification: DSSC-8672
# SSM API — Add `faxNumber` to User Profile Detail Endpoint

**Service:** `mit-surgical`
**Epic:** Fax Management
**Story Type:** Backend API
**Endpoint:** `GET /user/profile/detail`
**Related Spec:** [Backend Technical Specification - TXAUS Fax Management](../../../../../../Documents/Fax%20Management/Backend%20Technical%20Specification%20-%20TXAUS%20Fax%20Management.md)

---

## 1. Background & Business Context

Fax Management requires fax numbers to be visible in the user profile detail payload so schedulers can see and verify fax routing context without additional lookups.

For profile detail:

- Office Scheduler users need practice `faxNumber` in both:
  - `primaryPractice`
  - `preference.practices[]`
- OR Scheduler users need unit/facility `faxNumber` in both:
  - `primaryHospital.units[]`
  - `preference.hospitals[].units[]`

This story extends the existing detail response contract only; no new endpoint is introduced.

---

## 2. Goals

1. Return practice `faxNumber` in `GET /user/profile/detail` for office scheduler practice objects.
2. Return unit `faxNumber` in `GET /user/profile/detail` for OR scheduler unit objects.
3. Preserve existing response shape and authorization behavior.

---

## 3. Out of Scope

- Any changes to path, method, or auth for `GET /user/profile/detail`.
- Any data backfill or migration in MongoDB.
- Any UI changes.
- Changes to other user profile endpoints (`/user/profile/`, update APIs).

---

## 4. Current State

### 4.1 Existing Behavior

The profile detail endpoint already returns:

- `primaryPractice` and `preference.practices[]` for office schedulers.
- `primaryHospital` and `preference.hospitals[]` (including `units[]`) for OR schedulers.

However, the detail DTOs used by `/user/profile/detail` currently do not expose `faxNumber`:

- `PracticeDetailDTO` has `id`, `name`, `address`, `city`, `state`, `zipCode`, `euid`, `surgeons`.
- `UnitDetailDTO` has `id`, `name`, `hospitalName`, `openTimeConfig`, `addressRequired` (and ignored `scheduleConfig`).

Meanwhile, upstream source APIs/DTOs/entities already contain `faxNumber`:

- `procedure/dto/PracticeDTO`
- `procedure/dto/UnitDTO`

So the gap is in user profile detail DTO shape, not in core practice/unit domain storage.

### 4.2 Affected Components

| Component | Current Behavior | Gap |
|---|---|---|
| `GET /user/profile/detail` (`ProfileContract`) | Returns `UserDetailDTO` | No direct contract change needed; response model must include new fields |
| `userprofile/dto/detail/PracticeDetailDTO` | Used for `primaryPractice` and `preference.practices[]` | Missing `faxNumber` |
| `userprofile/dto/detail/UnitDetailDTO` | Used for hospital units in detail response | Missing `faxNumber` |
| `SurgicalUserAdministrator#createUserDetailDTO` and helpers | Maps practice/unit responses into detail DTOs | Will start emitting `faxNumber` once fields exist on detail DTOs |

---

## 5. Target State

### 5.1 Data/DTO Changes

| DTO | Field | Type | Required | Notes |
|---|---|---|---|---|
| `PracticeDetailDTO` | `faxNumber` | `String` | No | Office scheduler: surfaced in `primaryPractice` and `preference.practices[]` |
| `UnitDetailDTO` | `faxNumber` | `String` | No | OR scheduler: surfaced in `primaryHospital.units[]` and `preference.hospitals[].units[]` |

### 5.2 API Contract

| Method | Path | Change |
|---|---|---|
| `GET` | `/user/profile/detail` | Add `faxNumber` field in nested practice and unit detail objects |

No response status code changes.

### 5.3 Authorization

No change. Continue using existing scope enforcement on `ProfileContract#getUserDetail` (`SCOPE_USER_PROFILE_READ`).

---

## 6. Code Changes

### 6.1 Files to Update

```
mit-surgical/src/main/java/org/ascension/swe/surgical/userprofile/
├── dto/detail/PracticeDetailDTO.java   → add String faxNumber with schema annotation
└── dto/detail/UnitDetailDTO.java       → add String faxNumber with schema annotation
```

### 6.2 Why This Is Sufficient

- `SurgicalUserAdministrator` currently maps API response bodies for practice/unit lookups into detail DTOs using `createTypeMap().map(...)`.
- The upstream practice/unit source models already contain `faxNumber`, so adding the destination fields allows mapping to flow through automatically.
- No repository/query changes are required for this story because practice and unit endpoints already return fax numbers.

---

## 7. API Response — Target State

### 7.1 Office Scheduler (excerpt)

```json
{
  "primaryPractice": {
    "id": "612585e5cab88c0011e428c7",
    "name": "Nashville Sports Medicine and Orthopaedic Center",
    "address": "2004 Hayes St",
    "city": "Nashville",
    "state": "TN",
    "zipCode": "37203",
    "euid": "1111111111",
    "faxNumber": "555-555-1111",
    "surgeons": [
      { "id": "6125885c45cef900110ce4b5", "name": "James", "lastName": "Broome" }
    ]
  },
  "preference": {
    "practices": [
      {
        "id": "612585e5cab88c0011e428c7",
        "name": "Nashville Sports Medicine and Orthopaedic Center",
        "faxNumber": "555-555-1111"
      },
      {
        "id": "5e85e614c99ab800147ca601",
        "name": "Urology Associates, P.C.",
        "faxNumber": "555-555-2222"
      }
    ]
  }
}
```

### 7.2 OR Scheduler (excerpt)

```json
{
  "primaryHospital": {
    "id": "60580a242c07803901656b56",
    "name": "Sacred Heart Pensacola",
    "units": [
      {
        "id": "60580ad82c07803901656b58",
        "name": "GSP Main OR",
        "hospitalName": "Sacred Heart Pensacola",
        "openTimeConfig": true,
        "addressRequired": false,
        "faxNumber": "512-123-1234"
      }
    ]
  },
  "preference": {
    "hospitals": [
      {
        "id": "60580a242c07803901656b56",
        "name": "Sacred Heart Pensacola",
        "units": [
          {
            "id": "60580ad82c07803901656b59",
            "name": "GSP Surgery Center",
            "faxNumber": "512-123-1223"
          }
        ]
      }
    ]
  }
}
```

`faxNumber` is nullable and should return `null` when not present in source data.

---

## 8. Acceptance Criteria

### AC-1: Office scheduler primary practice includes fax number

**Given** an office scheduler profile whose primary practice has `faxNumber` in practice data  
**When** `GET /user/profile/detail` is called with valid auth  
**Then** `primaryPractice.faxNumber` is present and matches source practice data

### AC-2: Office scheduler preferred practices include fax number

**Given** an office scheduler profile with one or more preference practices  
**When** `GET /user/profile/detail` is called  
**Then** each entry in `preference.practices[]` contains `faxNumber`

### AC-3: OR scheduler primary hospital units include fax number

**Given** an OR scheduler profile with unit preferences  
**When** `GET /user/profile/detail` is called  
**Then** each unit in `primaryHospital.units[]` contains `faxNumber`

### AC-4: OR scheduler preference hospital units include fax number

**Given** an OR scheduler profile with hospitals in preference  
**When** `GET /user/profile/detail` is called  
**Then** each unit in `preference.hospitals[].units[]` contains `faxNumber`

### AC-5: Null-safe behavior

**Given** source practice/unit has no `faxNumber` value  
**When** `GET /user/profile/detail` is called  
**Then** response returns the agreed serialization behavior for missing fax values (explicit `null` or field omission) and no error is thrown

### AC-6: No regression for existing fields

**Given** existing fields such as `name`, `address`, `city`, `state`, `zipCode`, `euid`, `surgeons`, `openTimeConfig`, and `addressRequired`  
**When** `GET /user/profile/detail` is called after the change  
**Then** those fields continue to be returned unchanged

---

## 9. Testing Requirements

| Test | Type | File |
|---|---|---|
| Office scheduler detail includes `primaryPractice.faxNumber` and `preference.practices[].faxNumber` | Unit | `SurgicalUserAdministratorTest` (new or updated) |
| OR scheduler detail includes `primaryHospital.units[].faxNumber` and `preference.hospitals[].units[].faxNumber` | Unit | `SurgicalUserAdministratorTest` (new or updated) |
| Null fax number does not break detail response mapping and maps safely in detail DTOs | Unit | `SurgicalUserAdministratorTest` (new or updated) |
| `/user/profile/detail` contract returns new nested fields in JSON | Integration | `UserProfileControllerIT` (new or updated) |
| `/user/profile/detail` contract enforces one consistent null serialization behavior for missing fax values | Integration | `UserProfileControllerIT` (new or updated) |

---

## 10. Definition of Done

- [ ] `PracticeDetailDTO` includes `faxNumber`
- [ ] `UnitDetailDTO` includes `faxNumber`
- [ ] `/user/profile/detail` returns `faxNumber` for office scheduler practice sections
- [ ] `/user/profile/detail` returns `faxNumber` for OR scheduler unit sections
- [ ] All acceptance criteria pass in QA
- [ ] Unit/integration tests added or updated
- [ ] Code reviewed and merged

---

## 11. Open Questions

| # | Question | Owner |
|---|---|---|
| 1 | Should `faxNumber` formatting be normalized (e.g., `555-555-1111` vs `+15555551111`) at API layer, or returned as-is from source data? | Product + Backend |
| 2 | For null values, should field be explicitly serialized as `null` or omitted consistently? | Backend + UI |
