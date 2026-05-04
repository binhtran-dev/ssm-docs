# DSSC-8575 Spec Review: Findings vs. Figma Design & Architecture

**Reviewed:** DSSC-8575-spec.md  
**Cross-referenced against:** Figma node `971:14724`, Backend Technical Specification, APIs.md, UI Breakdown (Potential Stories), Unified Analysis, Fax Management PRD, `ReviewStatus.java`, `DocumentCategoryEnum.java`, `DocumentEntity.java`  
**Date:** 2026-05-03

---

## Summary

16 findings across 4 severity levels. 4 are critical blockers that will cause integration failures between the UI and API if not resolved before implementation.

| Severity | Count |
|---|---|
| 🔴 Critical | 4 (3 resolved) |
| 🟠 High | 3 (1 resolved) |
| 🟡 Medium | 6 (3 resolved) |
| 🟢 Low | 3 (3 resolved) |

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

**Resolution:** ✅ **Resolved** — `APIs.md` is an outdated document. The UI expands tabs client-side: when the "Current" tab is selected, the UI sends `reviewStatus=WAITING,REVIEWED`. The API only receives valid `ReviewStatus` enum values; no server-side `CURRENT` handling is needed.

---

### 3. Data Model Architecture Conflict: Root Fields vs. Nested `metadata`

**Resolution:** ✅ **Resolved** — `APIs.md` is an outdated document. The actual implementation in `DocumentEntity.java` and `DocumentDTO.java` has always used flat root-level fields; no nested `metadata` sub-document was ever built. The spec correctly follows the existing codebase. `procedureDate` is added as a root field consistent with how `patientFirstName`, `patientLastName`, `identifier`, `cptCodes`, `category`, and `dob` are already stored.

---

### 4. Endpoint Path Conflicts With Established Architecture

**Spec** creates `GET /v1/faxes/search` under a new `/v1/faxes` resource.

All other documentation models the fax inbox as an extension of `GET /v2/documents`. The existing codebase has `DocumentContract` (`/v1/documents`) and `DocumentV2Contract` (`/v2/documents`). Introducing a `/v1/faxes` path creates a second divergent access path for the same `document` MongoDB collection.

**Impact:** Architectural drift, duplicate access patterns, and potential security surface confusion. Other stories that extend the document list (counts, bulk update, etc.) would have no clear home if a parallel path is created.

**Resolution:** ✅ **Resolved** — `/v1/faxes/search` is confirmed as a deliberate new resource, providing a fax-inbox-specific access path separate from the generic document CRUD path.

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

**Resolution:** ✅ **Resolved** — `FaxStatusCountsDTO` is removed. `counts` is typed as `Map<ReviewStatus, Integer>` in `FaxSearchResponse`, which Jackson serializes using the enum name as the key — producing `"WAITING"`, `"REVIEWED"`, `"DATA_CONFLICT"`, `"CLOSED"` directly, matching the expected JSON.

---

### 6. `totalPages` / `size` Missing From Response

**Spec** response returns only `totalCount` and `page`.

**Figma** shows a pagination control. To render page numbers, the UI needs either `totalPages` or both `totalCount` + `size` echoed back.

**APIs.md** response includes `totalElements`, `totalPages`, `size`, and `hasNext`.

**Resolution:** ✅ **Resolved** — `size` is added to `FaxSearchResponse`. The UI can derive `totalPages = ceil(totalCount / size)` client-side.

---

### 7. `FaxSummaryDTO` Field Names Inconsistent With All Other API Contracts

| Spec DTO field | APIs.md / Backend Tech Spec / Figma equivalent | Issue |
|---|---|---|
| `firstName` | `patientFirstName` | Inconsistent; UI may expect `patientFirstName` |
| `lastName` | `patientLastName` | Inconsistent; UI may expect `patientLastName` |
| `DOB` | `dob` | ~~Uppercase query param used as response field name~~ — renamed to `dob` |
| `createdDate` | `createdAt` | Different names for the same concept |

**Resolution:** ✅ **Resolved** — The field names in `FaxSummaryDTO` (`firstName`, `lastName`, `dob`, `createdDate`) are intentional aliases for this fax-specific endpoint. They differ from the underlying entity fields (`patientFirstName`, `patientLastName`, `dob`, `createdAt`) by design to match the fax inbox UI contract.

---

## 🟡 Medium Findings

### 8. No Received-Date Range Filter

**Figma** and the UI Breakdown reference date range filtering.  
**APIs.md** includes `dateFrom` / `dateTo` parameters for the received/created date.  
**Spec** only supports `dob` and `procedureDate` as date filters — there is no way to filter faxes by the received date range, which is a primary inbox filter.

**Resolution:** ⏭️ **Out of Scope** — Date range filtering on received date (`createdAt`) is deferred. Not included in this story.

---

### 9. `sortModel` Format Is Non-Standard and Field Name Differs

**Spec** format: `createdDate:desc` (colon-separated, custom field name).  
**APIs.md** format: `createdAt,desc` (comma-separated, Spring Data standard).

The field name also differs: spec uses `createdDate` externally, maps it to `createdAt` internally.

**Resolution:** ✅ **Resolved** — The colon-separated `<field>:<direction>` format with the `createdDate` external alias is intentional for this endpoint. `createdDate` maps internally to the entity field `createdAt`. This is explicitly documented in §7.3 of the spec.

---

### 10. Only `createdDate` Supported for Sorting

**Figma** shows column-header sorting on all visible columns (received date, procedure date, practice name, etc.). The spec only handles `createdDate` and silently falls back to `createdAt:desc` for any unrecognised field — no error, no indication to the UI.

Open Question #2 in the spec acknowledges this but leaves it unresolved.

**Resolution:** ✅ **Resolved** — All `FaxSummaryDTO` fields are now supported for sorting (`createdDate`, `procedureDate`, `practiceName`, `identifier`, `firstName`, `lastName`, `dob`, `category`, `reviewStatus`). An unrecognised `sortModel` value returns `400 Bad Request` so the UI fails visibly.

---

### 11. `DATA_CONFLICT` vs. `DATA_CONFLICTS` — Cross-Document Inconsistency

The actual `ReviewStatus.java` enum:
```java
public enum ReviewStatus { WAITING, REVIEWED, DATA_CONFLICT, CLOSED }
```

APIs.md and Backend Tech Spec use `DATA_CONFLICTS` (plural) in several places. The spec correctly uses `DATA_CONFLICT` — but the inconsistency must be resolved across all documentation so that the frontend uses the correct string.

**Resolution:** ✅ **Resolved** — `DATA_CONFLICT` (singular) is confirmed as the canonical value, matching the `ReviewStatus.java` enum. All documentation referencing `DATA_CONFLICTS` (plural) should be updated accordingly.

---

### 12. `DOB` Uppercase Query Param Requires Explicit Binding Annotation

**Resolution:** ✅ **Resolved** — The query parameter is renamed to lowercase `dob`, matching the Java field name convention. No binding annotation needed.

---

### 13. `practiceFaxNumber` (Sender Fax Number) Not in Response

`DocumentEntity` has both `facilityFaxNumber` (receiver/queue) and `practiceFaxNumber` (sender/practice). `FaxSummaryDTO` includes `practiceName` but not `practiceFaxNumber`. If the UI needs to display or identify the sending office's fax number (which is visible in the Figma list), it will not be available from this endpoint.

**Resolution:** ✅ **Resolved** — `practiceFaxNumber` is not included in the response. It is not in the requirements for this story.

---

## 🟢 Low Findings

### 14. `surgeon` Field Not Addressed in Data Model

The PRD lists "Entered Surgeon Name" as required metadata. APIs.md includes `surgeon` in the `metadata` object. Neither `DocumentEntity` (current or proposed) nor `FaxSummaryDTO` includes this field.

**Resolution:** ✅ **Resolved** — `surgeon` is not a fax list column. It is entered by the user in the PDF viewer metadata panel and belongs to the metadata update story. It does not need to appear in `FaxSummaryDTO` for this search endpoint. Defer to the metadata update story.

---

### 15. `counts` in Search Response vs. Task Card Counts Are Different Concerns

The spec's `counts` in the search response is a status breakdown scoped to the queried fax numbers — not the same as the per-queue task card counts shown on the Figma dashboard (`GET /v2/documents/counts`).

The spec does not explain the relationship between the two, which may cause confusion during UI integration.

**Resolution:** ✅ **Resolved** — The spec's `counts` is the tab-bar badge breakdown for the queried fax numbers (i.e. how many faxes in each `ReviewStatus` across the selected queues). This is already documented in §7.5 and AC-4 of the spec. The task card aggregation (`GET /v2/documents/counts`) is a separate endpoint for the dashboard and is out of scope for this story.

---

### 16. `category=NULL` String Sentinel Is Fragile

Using the literal string `"NULL"` to represent uncategorised documents is ambiguous and non-standard. There is no mention of case-insensitive matching. A request with `category=null` (lowercase) would behave differently than `category=NULL`.

**Resolution:** ✅ **Resolved** — `NULL` is a supported category filter value. Category contract:
- `BOARDING` — identified as a boarding sheet via radio button in the PDF viewer
- `SUPPORT` — identified as a support document via radio button in the PDF viewer
- `NULL` — not yet categorised; displayed as `--` in the list UI
- **"All"** — UI sends `category=BOARDING,SUPPORT,NULL` to include all three groups

`NULL` is parsed case-insensitively. Unrecognised values return `400 Bad Request`.

---

## Recommended Actions Before Implementation

1. **Align on queue identifier** — decide `faxNumbers` vs. `queueId` with UI team and Backend Tech Spec owner.
2. ~~**Handle `CURRENT` tab** — add explicit expansion logic or document client-side responsibility.~~ ✅ Resolved — client-side expansion; UI sends `WAITING,REVIEWED`.
3. ~~**Agree on data model location** — root fields vs. `metadata` sub-document with team sign-off.~~ ✅ Resolved — flat root fields are the implementation reality; `APIs.md` is outdated.
4. ~~**Confirm endpoint path** — `/v1/faxes/search` vs. `/v2/documents` extension.~~ ✅ Resolved — `/v1/faxes/search` confirmed.
5. ~~**Fix DTO/JSON inconsistencies** — counts DTO field names, summary DTO field names (#7), `DOB` binding annotation (#12).~~ ✅ All resolved.
6. ~~**Add `totalPages` to response** — pending team input on UI pagination requirements.~~ ✅ Resolved — `size` and `totalPages` added to `FaxSearchResponse`.
7. ~~**Resolve `DATA_CONFLICT` spelling** across all documentation.~~ ✅ Resolved — `DATA_CONFLICT` (singular) is canonical.
