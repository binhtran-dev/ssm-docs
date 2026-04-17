# Implementation Plan: DSSC-8643
**Branch:** `feature/DSSC-8643-practice-fax-ministry`
**Files to change: 3 production, 1 test**

---

## Step 1 — `entity/Practice.java`

**File:** Practice.java

Current last field before getters: `private String primaryHospital;`

Add after `primaryHospital` field declaration:

```java
private String faxNumber;
```

Add getter/setter after `setPrimaryHospital()` (before any existing `toString()`):

```java
public String getFaxNumber() {
    return faxNumber;
}

public void setFaxNumber(String faxNumber) {
    this.faxNumber = faxNumber;
}
```

No Lombok — follows existing explicit getter/setter style on this entity.

---

## Step 2 — `dto/PracticeDTO.java`

**File:** PracticeDTO.java

This DTO uses `@Data` (Lombok) — only the field declaration is needed. Add after `distributionEmail`:

```java
@Schema(name = "Fax Number", title = "Fax number for the practice", example = "+15125550101")
private String faxNumber;
```

Also update `toString()` to include `faxNumber` (since `@Data` doesn't exist on this class — it uses a manually written `toString()`):

```java
// In the existing toString(), add before the closing '}'
", faxNumber='" + faxNumber + '\'' +
```

> Wait — from the earlier read, `PracticeDTO` in `procedure/dto/` **does** have `@Data` AND a manually written `toString()`. The `@Data` annotation means no explicit getter/setter needed, but the manual `toString()` must be updated.

**Add the field:**
```java
@Schema(name = "Fax Number", title = "Fax number for the practice", example = "+15125550101")
private String faxNumber;
```

**Update `toString()`** — change:
```java
", distributionEmail='" + distributionEmail + '\'' +
        '}';
```
To:
```java
", distributionEmail='" + distributionEmail + '\'' +
        ", faxNumber='" + faxNumber + '\'' +
        '}';
```

---

## Step 3 — `resource/contract/PracticeContract.java`

**File:** PracticeContract.java

Current `@PreAuthorize` on `getAllPractice` (line 50):

```java
@PreAuthorize("hasAuthority('SCOPE_dssc_schedule_app.practice.read')")
```

Replace with:

```java
@PreAuthorize("hasAnyAuthority('SCOPE_dssc_schedule_app.practice.read', 'SCOPE_dssc_schedule_app.surgery_schedule.read')")
```

> `SCOPE_SURGERY_READ` from `SecurityUtil` resolves to `hasAuthority(...)` (a full SpEL expression string), not just the scope string — it cannot be passed to `hasAnyAuthority`. Use the literal scope value directly.

Also update the `@Operation` `parameters` annotation to document `primaryMinistry`:

```java
@Operation(method = "GET", description = "List of all Practices", operationId = "getAllPractice",
        parameters = {
            @Parameter(in = ParameterIn.QUERY, name = "primaryMinistry", required = false,
                description = "Filter practices by primary ministry identifier (e.g. TXAUS)",
                schema = @Schema(implementation = String.class)),
            @Parameter(in = ParameterIn.PATH, name = "queryParams", required = false,
                description = "Query Parameters", schema = @Schema(implementation = Map.class))
        }
)
```

---

## Step 4 — Test Updates

### 4.1 `PracticeControllerTest.java`

Add scope-level tests against `getAllPractice` using `@WithMockUser` or `SecurityMockMvcRequestPostProcessors.jwt()`:

```java
@Test
public void getAllPractice_withSurgeryReadScope_returns200() throws Exception {
    // given practices exist
    mockMvc.perform(get("/practices?primaryMinistry=TXAUS")
            .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_dssc_schedule_app.surgery_schedule.read"))))
        .andExpect(status().isOk());
}

@Test
public void getAllPractice_withNoScope_returns403() throws Exception {
    mockMvc.perform(get("/practices?primaryMinistry=TXAUS")
            .with(jwt()))
        .andExpect(status().isForbidden());
}
```

---

## Summary

| File | Change Type | ~Lines Added |
|---|---|---|
| `entity/Practice.java` | Add field + getter/setter | +8 |
| `procedure/dto/PracticeDTO.java` | Add field + update `toString()` | +4 |
| `resource/contract/PracticeContract.java` | Update `@PreAuthorize` + `@Parameter` doc | +5 |
| `PracticeControllerTest.java` | Add 2 scope-level tests | +20 |

**Production files: 3 · Test files: 1 · New files: 0**

## Post-Deployment Notes

- No cache flush required (Practice endpoints are not cached).
- No MongoDB migration required — existing documents return `null` for `faxNumber`.
- QA smoke test: insert one practice document with `faxNumber` and `primaryMinistry = "<env-ministry>"`, then call `GET /practices?primaryMinistry=<env-ministry>` and verify `faxNumber` appears in the response.