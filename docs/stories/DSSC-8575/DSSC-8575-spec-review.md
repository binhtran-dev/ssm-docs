# DSSC-8575 Spec Review: Findings vs. Figma Design & Architecture

**Reviewed:** DSSC-8575-spec.md  
**Cross-referenced against:** Figma node `971:14724`, Backend Technical Specification, APIs.md, UI Breakdown (Potential Stories), Unified Analysis, Fax Management PRD, `ReviewStatus.java`, `DocumentCategoryEnum.java`, `DocumentEntity.java`  
**Date:** 2026-05-03

---

## Summary

16 findings across 4 severity levels. 4 are critical blockers that will cause integration failures between the UI and API if not resolved before implementation.

| Severity | Count |
|---|---|
| 🔴 Critical | 4 |
| 🟠 High | 3 |
| 🟡 Medium | 6 |
| 🟢 Low | 3 |

---

## 🔴 Critical Findings

### 1. Queue Filtering: `faxNumbers` vs. `queueId`

**Spec** parameter: `faxNumbers` — a CSV of raw facility fax numbers (e.g., `5122222222,5122121234`).

**Figma** shows a **Queue/facility dropdown** that resolves unit names from `mit-surgical`. The Feature Split doc explicitly states:
> _"Will use queueId that comes from unit info and aggregate non-duplicates for unit param"_

All other documentation (Backend Tech Spec, APIs.md, Unified Analysis) uses `queueId` as the queue identifier throughout. The UI dropdown will emit a unit/queue ID — not a raw fax number.

**Impact:** The UI and API will be unable to communicate. The UI sends a queue ID; the API expects a fax number list.

**Resolution needed:** Align on whether the inbox filter parameter is `faxNumbers` or `queueId`. If `faxNumbers` is intentional (because the fax-number-to-unit mapping isn't yet implemented), this decision must be explicitly called out and the Figma dropdown behaviour must be updated to match.

---

### 2. Missing `CURRENT` Status Tab Handling

**Figma** shows a `CURRENT` tab that displays both `WAITING` and `REVIEWED` faxes together.

**APIs.md** accounts for this:
> _"CURRENT is a menu/status bucket and should be computed as WAITING + REVIEWED"_

**Spec** defines no handling for `CURRENT` as a `status` CSV value. If the UI sends `status=CURRENT`, parsing against the `ReviewStatus` enum will throw an exception or return a 400.

**Impact:** The primary tab in the inbox UI will be broken.

**Resolution needed:** Add a `CURRENT` special case that expands to `[WAITING, REVIEWED]` during request parsing, or document that the UI must expand this client-side before calling the API.

---

### 3. Data Model Architecture Conflict: Root Fields vs. Nested `metadata`

**Spec** adds `fin` and `procedureDate` as root-level fields on `DocumentEntity`.

**Backend Technical Specification** defines a nested `metadata` object:
> _"Nested Object (MetadataDTO): All data manually entered or visually extracted by the user (fin, patientFirstName, patientLastName, procedureDate, cptCodes, category) will be grouped within an embedded object named metadata."_

**APIs.md** models all these fields under `metadata.fin`, `metadata.patientFirstName`, `metadata.procedureDate`, etc. The upcoming `PATCH /v2/documents/{id}/metadata` story also writes to this nested structure.

**Impact:** Adding `fin` and `procedureDate` at the root contradicts the agreed data model and will create inconsistency with the `PATCH /metadata` endpoint. Future migration cost increases.

**Resolution needed:** Either update this spec to use the `metadata` sub-document, or formally document a deviation from the Backend Tech Spec with the team's explicit sign-off.

---

### 4. Endpoint Path Conflicts With Established Architecture

**Spec** creates `GET /v1/faxes/search` under a new `/v1/faxes` resource.

All other documentation models the fax inbox as an extension of `GET /v2/documents`. The existing codebase has `DocumentContract` (`/v1/documents`) and `DocumentV2Contract` (`/v2/documents`). Introducing a `/v1/faxes` path creates a second divergent access path for the same `document` MongoDB collection.

**Impact:** Architectural drift, duplicate access patterns, and potential security surface confusion. Other stories that extend the document list (counts, bulk update, etc.) would have no clear home if a parallel path is created.

**Resolution needed:** Confirm with the team whether this should be a new `/v1/faxes` resource (as a deliberate separation of concerns) or an extension of `GET /v2/documents` as specified in Backend Tech Spec and APIs.md. Document the decision explicitly.

---

## 🟠 High Findings

### 5. `FaxStatusCountsDTO` Field Names Conflict With JSON Example

**Section 8.3** defines the DTO with Java camelCase fields:
```java
private int waiting;
private int reviewed;
private int dataConflict;
private int closed;
```

**Section 9** (full response example) shows:
```json
"counts": { "DATA_CONFLICT": 3, "WAITING": 12, "REVIEWED": 3, "CLOSED": 1 }
```

With default Jackson serialization, `dataConflict` serializes to `"dataConflict"`, not `"DATA_CONFLICT"`. The spec's own DTO and example are inconsistent.

**Resolution needed:** Either add `@JsonProperty("DATA_CONFLICT")` etc. on each field, or restructure the DTO as a `Map<ReviewStatus, Integer>` / use the `ReviewStatus` enum as keys. The JSON key format must match what the UI expects.

---

### 6. `totalPages` / `size` Missing From Response

**Spec** response returns only `totalCount` and `page`.

**Figma** shows a pagination control. To render page numbers, the UI needs either `totalPages` or both `totalCount` + `size` echoed back.

**APIs.md** response includes `totalElements`, `totalPages`, `size`, and `hasNext`.

**Resolution needed:** Add `totalPages` (and optionally `size`) to `FaxSearchResponse`. Minimum: `totalPages = ceil(totalCount / size)`.

---

### 7. `FaxSummaryDTO` Field Names Inconsistent With All Other API Contracts

| Spec DTO field | APIs.md / Backend Tech Spec / Figma equivalent | Issue |
|---|---|---|
| `firstName` | `patientFirstName` | Inconsistent; UI may expect `patientFirstName` |
| `lastName` | `patientLastName` | Inconsistent; UI may expect `patientLastName` |
| `DOB` | `dob` | Uppercase query param used as response field name |
| `createdDate` | `createdAt` | Different names for the same concept |

**Resolution needed:** Align field names with the established contract. Use `patientFirstName`, `patientLastName`, `dob`, and `createdAt` (or confirm intentional aliasing with `@JsonProperty`).

---

## 🟡 Medium Findings

### 8. No Received-Date Range Filter

**Figma** and the UI Breakdown reference date range filtering.  
**APIs.md** includes `dateFrom` / `dateTo` parameters for the received/created date.  
**Spec** only supports `DOB` and `procedureDate` as date filters — there is no way to filter faxes by the received date range, which is a primary inbox filter.

**Resolution needed:** Add `dateFrom` / `dateTo` (or `receivedFrom` / `receivedTo`) optional query parameters scoped to `createdAt`.

---

### 9. `sortModel` Format Is Non-Standard and Field Name Differs

**Spec** format: `createdDate:desc` (colon-separated, custom field name).  
**APIs.md** format: `createdAt,desc` (comma-separated, Spring Data standard).

The field name also differs: spec uses `createdDate` externally, maps it to `createdAt` internally.

**Resolution needed:** Align the sort format with the platform convention. If `createdDate` is used as the external alias, document it explicitly. Using the colon separator is non-standard and may surprise frontend developers used to the rest of the API surface.

---

### 10. Only `createdDate` Supported for Sorting

**Figma** shows column-header sorting on all visible columns (received date, procedure date, practice name, etc.). The spec only handles `createdDate` and silently falls back to `createdAt:desc` for any unrecognised field — no error, no indication to the UI.

Open Question #2 in the spec acknowledges this but leaves it unresolved.

**Resolution needed:** Either explicitly list all supported sort fields (and return a 400 for unsupported values so the UI fails visibly), or confirm that only `createdDate` sort is in scope for this story and document that limitation.

---

### 11. `DATA_CONFLICT` vs. `DATA_CONFLICTS` — Cross-Document Inconsistency

The actual `ReviewStatus.java` enum:
```java
public enum ReviewStatus { WAITING, REVIEWED, DATA_CONFLICT, CLOSED }
```

APIs.md and Backend Tech Spec use `DATA_CONFLICTS` (plural) in several places. The spec correctly uses `DATA_CONFLICT` — but the inconsistency must be resolved across all documentation so that the frontend uses the correct string.

**Resolution needed:** Confirm `DATA_CONFLICT` (singular) is the canonical value. Update all documents that use `DATA_CONFLICTS`.

---

### 12. `DOB` Uppercase Query Param Requires Explicit Binding Annotation

The query parameter is named `DOB` (uppercase). Spring's `@ModelAttribute` binding on `FaxSearchRequest` will look for a `dob` field by default (matching Java field name convention). Without `@RequestParam("DOB")` on the field or a custom converter, the `DOB` parameter will silently not bind.

**Resolution needed:** Add `@RequestParam("DOB")` annotation to the `dob` field in `FaxSearchRequest`, or rename the query parameter to lowercase `dob` and update the spec examples.

---

### 13. `practiceFaxNumber` (Sender Fax Number) Not in Response

`DocumentEntity` has both `facilityFaxNumber` (receiver/queue) and `practiceFaxNumber` (sender/practice). `FaxSummaryDTO` includes `practiceName` but not `practiceFaxNumber`. If the UI needs to display or identify the sending office's fax number (which is visible in the Figma list), it will not be available from this endpoint.

**Resolution needed:** Confirm with the UI team whether `practiceFaxNumber` is needed in the list response. Add it to `FaxSummaryDTO` if so.

---

## 🟢 Low Findings

### 14. `surgeon` Field Not Addressed in Data Model

The PRD lists "Entered Surgeon Name" as required metadata. APIs.md includes `surgeon` in the `metadata` object. Neither `DocumentEntity` (current or proposed) nor `FaxSummaryDTO` includes this field.

**Resolution needed:** Either add `surgeon` to the data model additions in this story (alongside `fin` and `procedureDate`), or explicitly defer it to the metadata update story with a ticket reference.

---

### 15. `counts` in Search Response vs. Task Card Counts Are Different Concerns

The spec's `counts` in the search response is a status breakdown scoped to the queried fax numbers — not the same as the per-queue task card counts shown on the Figma dashboard (`GET /v2/documents/counts`).

The spec does not explain the relationship between the two, which may cause confusion during UI integration.

**Resolution needed:** Add a clarifying note in the spec that `counts` here is the status breakdown for the current queue filter only, and is distinct from the task card aggregation endpoint.

---

### 16. `category=NULL` String Sentinel Is Fragile

Using the literal string `"NULL"` to represent uncategorised documents is ambiguous and non-standard. There is no mention of case-insensitive matching. A request with `category=null` (lowercase) would behave differently than `category=NULL`.

**Resolution needed:** Either enforce and document case-insensitive parsing for `"NULL"`, or replace the sentinel with an explicit value like `UNCATEGORIZED` / `NONE` for clarity.

---

## Recommended Actions Before Implementation

1. **Align on queue identifier** — decide `faxNumbers` vs. `queueId` with UI team and Backend Tech Spec owner.
2. **Handle `CURRENT` tab** — add explicit expansion logic or document client-side responsibility.
3. **Agree on data model location** — root fields vs. `metadata` sub-document with team sign-off.
4. **Confirm endpoint path** — `/v1/faxes/search` vs. `/v2/documents` extension.
5. **Fix DTO/JSON inconsistencies** — counts DTO field names, summary DTO field names, `DOB` binding.
6. **Add `totalPages` to response** — required for pagination UI.
7. **Resolve `DATA_CONFLICT` spelling** across all documentation.
