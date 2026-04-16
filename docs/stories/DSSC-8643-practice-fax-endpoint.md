# DSSC-8643 — SSM API: New Endpoint for Practice (Sender) Faxes

## Story Summary

> **Title:** SSM - API - New Endpoint for Practice (Sender) Faxes
>
> Add `faxNumber` to the `practice` MongoDB collection and expose a new API endpoint to retrieve practices filtered by ministry.

---

## Scope of Changes — `mit-surgical`

### Task 1: Add `faxNumber` to Practice

Add the field to both the entity and the DTO. MongoDB is schema-less, so no data migration script is required. Existing documents will return `null` for `faxNumber` until updated via the existing `POST /practice/` or `PUT /practice/` endpoints.

#### `src/main/java/.../procedure/entity/Practice.java`

```java
private String faxNumber;

public String getFaxNumber() { return faxNumber; }
public void setFaxNumber(String faxNumber) { this.faxNumber = faxNumber; }
```

#### `src/main/java/.../procedure/dto/PracticeDTO.java`

```java
private String faxNumber;

public String getFaxNumber() { return faxNumber; }
public void setFaxNumber(String faxNumber) { this.faxNumber = faxNumber; }
```

---

### Task 2: New Endpoint — Retrieve Practices by Ministry

**Endpoint:** `GET /practice/ministry/{ministry}`

#### Layer-by-layer changes

| Layer | File | Change |
|---|---|---|
| Repository interface | `IPracticeRepository` | Add `List<Practice> findPracticesByMinistry(String ministry)` |
| Repository impl | `PracticeRepository` | Implement with `MongoTemplate` + `Criteria.where("primaryMinistry").is(ministry)` |
| Service interface | `IPracticeService` | Add `List<PracticeDTO> findAllPracticesByMinistry(String ministry)` |
| Service impl | `PracticeServiceImpl` | Call repo, map via `practiceListToPracticeDTOList()` |
| API contract | `PracticeContract` | Add `@GetMapping("/ministry/{ministry}")` with OpenAPI docs + `@PreAuthorize` |
| Controller | `PracticeController` | Delegate to service; return `200` or `204` |

---

### Implementation Detail

#### `IPracticeRepository`

```java
List<Practice> findPracticesByMinistry(String ministry) throws DataAccessException;
```

#### `PracticeRepository` (impl)

```java
@Override
public List<Practice> findPracticesByMinistry(String ministry) throws DataAccessException {
    try {
        Aggregation aggregation = Aggregation.newAggregation(
                Aggregation.match(Criteria.where("primaryMinistry").is(ministry)),
                getLookupOperation(),
                getDistributionEmailProject()
        );
        return mongoTemplate.aggregate(aggregation, Practice.class, Practice.class).getMappedResults();
    } catch (Exception ex) {
        throw ServiceDataExceptionHandler.handleDataException(ex);
    }
}
```

#### `IPracticeService`

```java
List<PracticeDTO> findAllPracticesByMinistry(String ministry) throws ServiceException;
```

#### `PracticeServiceImpl`

```java
@Override
public List<PracticeDTO> findAllPracticesByMinistry(String ministry) throws ServiceException {
    try {
        List<Practice> practiceList = practiceRepository.findPracticesByMinistry(ministry);
        return practiceListToPracticeDTOList(practiceList);
    } catch (Exception ex) {
        throw ServiceDataExceptionHandler.handleException(ex);
    }
}
```

#### `PracticeContract`

```java
@Operation(method = "GET", description = "List of Practices by Ministry", operationId = "getPracticesByMinistry",
        parameters = {@Parameter(in = ParameterIn.PATH, name = "ministry", required = true,
                description = "Ministry identifier", schema = @Schema(implementation = String.class))})
@ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Collection of Practices for the given ministry",
                content = @Content(mediaType = "application/json", schema = @Schema(implementation = List.class))),
        @ApiResponse(responseCode = "204", description = "No practices found for the given ministry"),
        @ApiResponse(responseCode = "400", description = "An exception was handled.",
                content = @Content(mediaType = "application/json", schema = @Schema(implementation = AscensionFault.class))),
        @ApiResponse(responseCode = "401", description = "The user was not authorized.",
                content = @Content(mediaType = "application/json", schema = @Schema(implementation = AscensionFault.class))),
        @ApiResponse(responseCode = "403", description = "The method was not authorized for the user.",
                content = @Content(mediaType = "application/json", schema = @Schema(implementation = AscensionFault.class)))})
@GetMapping(value = "/ministry/{ministry}")
@PreAuthorize("hasAuthority('SCOPE_dssc_schedule_app.practice.read')")
ResponseEntity getPracticesByMinistry(@PathVariable String ministry) throws ServiceException;
```

#### `PracticeController`

```java
@Override
public ResponseEntity getPracticesByMinistry(String ministry) throws ServiceException {
    List<PracticeDTO> practices = practiceService.findAllPracticesByMinistry(ministry);
    return !practices.isEmpty() ? ResponseEntity.ok(practices) : ResponseEntity.noContent().build();
}
```

---

## Files Changed Summary

```
mit-surgical/src/main/java/org/ascension/swe/surgical/procedure/
├── entity/Practice.java                          → add faxNumber field
├── dto/PracticeDTO.java                          → add faxNumber field
├── repository/IPracticeRepository.java           → add findPracticesByMinistry()
├── repository/impl/PracticeRepository.java       → implement findPracticesByMinistry()
├── service/IPracticeService.java                 → add findAllPracticesByMinistry()
├── service/impl/PracticeServiceImpl.java         → implement findAllPracticesByMinistry()
├── resource/contract/PracticeContract.java       → add GET /ministry/{ministry} endpoint declaration
└── resource/PracticeController.java              → implement getPracticesByMinistry()
```

---

## Notes

- The field `primaryMinistry` already exists on `Practice` — this is the field being queried.
- The `getDistributionEmailProject()` and `getLookupOperation()` helpers in `PracticeRepository` are reused to keep the aggregation consistent with other find methods.
- No new OAuth2 scope is needed; reuse `SCOPE_dssc_schedule_app.practice.read`.
- Unit tests should be added to `PracticeRepositoryTest`, `PracticeServiceImplTest`, and `PracticeControllerTest` following existing test patterns.
