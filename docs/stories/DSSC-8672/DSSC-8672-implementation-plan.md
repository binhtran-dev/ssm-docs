# Implementation Plan: DSSC-8672
# Add `faxNumber` to User Profile Detail Endpoint

**Service:** `mit-surgical`  
**Spec:** [DSSC-8672-spec.md](./DSSC-8672-spec.md)

---

## Overview

Two detail DTO fields are in scope. The `ModelMapper`-based mapping in `SurgicalUserAdministrator` reads from source API responses that already contain `faxNumber`, so no repository changes are needed and mapper changes are only required if explicit property maps suppress fields (none are expected). Work splits into:

1. DTO changes (2 files)
2. Unit test additions (1 file)
3. Integration test additions (1 file)

---

## Step 1 — Add `faxNumber` to `PracticeDetailDTO`

**File:** `src/main/java/org/ascension/swe/surgical/userprofile/dto/detail/PracticeDetailDTO.java`

Add after the `euid` field:

```java
@Schema(name = "FaxNumber", title = "Fax number for the practice", example = "555-555-1111")
private String faxNumber;
```

- This class uses Lombok `@Data` and `@Builder`, so no manual getter/setter/constructor changes are needed.
- `faxNumber` is optional; leave it without `@JsonInclude` so it serializes as `null` when absent (consistent with existing non-annotated fields on the DTO).

---

## Step 2 — Add `faxNumber` to `UnitDetailDTO`

**File:** `src/main/java/org/ascension/swe/surgical/userprofile/dto/detail/UnitDetailDTO.java`

Add after the `addressRequired` field:

```java
@Schema(name = "FaxNumber", title = "Facility fax number associated with the unit", example = "512-555-1234")
private String faxNumber;
```

- This class uses Lombok `@Data`; do **not** add manual getter/setter methods for `faxNumber`.

> **Why the mapping works automatically:** `SurgicalUserAdministrator` calls `createTypeMap().map(response.getBody(), PracticeDetailDTO.class)` and `createTypeMap().map(unitById.getBody(), UnitDetailDTO.class)`. The source types (`PracticeDTO`, `UnitDTO`) already declare `faxNumber`. `ModelMapper` (default matching strategy, with `Conditions.isNotNull()`) maps same-name fields automatically once the destination fields exist.

---

## Step 3 — Verify No Mapper Config Change Needed

Confirm that `ModelHelper.createTypeMap()` does not skip or suppress `faxNumber` via explicit property maps or type maps for `PracticeDetailDTO` / `UnitDetailDTO`.

**File to check:** `src/main/java/org/ascension/swe/surgical/procedure/util/ModelHelper.java`

If any `addMappings` block explicitly maps `PracticeDTO → PracticeDetailDTO` or `UnitDTO → UnitDetailDTO`, add `faxNumber` to that mapping. If none exists (likely, given convention-based mapping), no change needed here.

---

## Step 4 — Unit Tests in `SurgicalUserAdministratorTest`

**File:** `src/test/unit/java/org/ascension/swe/surgical/userprofile/service/impl/SurgicalUserAdministratorTest.java`

Add three new `@Test` methods. The existing `getDetailOfficeScheduler` and `getDetailORSchedule` tests stub `Practice` / `Unit` objects. Extend the same pattern with `faxNumber` set on stubs.

### 4.1 Office scheduler — `faxNumber` flows into `primaryPractice` and `preference.practices[]`

```java
@Test
void getDetailOfficeSchedulerIncludesFaxNumber() throws ServiceException {
    UserProfile userEntity = UserDTOUtil.getUserEntity(UserRole.DSSC_OFFICE_SCHEDULER);
    assert userEntity != null;
    when(userRepository.findById(anyString())).thenReturn(Optional.of(userEntity));
    when(api.getPracticeController()).thenReturn(practiceController);

    ProfilePractice profilePractice = userEntity.getPreference().getPractices().iterator().next();
    Practice practice = new Practice();
    practice.setId(profilePractice.getPracticeId().toString());
    practice.setFaxNumber("555-555-1111");
    when(api.getPracticeController().getPracticeById(anyString())).thenReturn(ResponseEntity.ok(practice));

    Surgeon surgeon = new Surgeon();
    surgeon.setId(profilePractice.getSurgeons().iterator().next().toString());
    when(api.getPracticeController().getSurgeonById(anyString())).thenReturn(ResponseEntity.ok(surgeon));

    Optional<UserDetailDTO> response = userManagement.getDetail(UserDTOUtil.getUserProfileDTO(UserRole.DSSC_OFFICE_SCHEDULER));
    assertThat(response.isPresent()).isTrue();
    assertThat(response.get().getPrimaryPractice().getFaxNumber()).isEqualTo("555-555-1111");
    response.get().getPreference().getPractices()
        .forEach(p -> assertThat(p.getFaxNumber()).isEqualTo("555-555-1111"));
}
```

### 4.2 OR scheduler — `faxNumber` flows into `preference.hospitals[].units[]` (and `primaryHospital.units[]` when primary is set)

```java
@Test
void getDetailORSchedulerIncludesFaxNumber() throws ServiceException {
    UserProfile userEntity = UserDTOUtil.getUserEntity(UserRole.DSSC_OR_SCHEDULER);
    assert userEntity != null;
    when(userRepository.findById(anyString())).thenReturn(Optional.of(userEntity));
    when(api.getHospitalController()).thenReturn(hospitalController);

    ProfileHospital profileHospital = userEntity.getPreference().getHospitals().iterator().next();
    Hospital hospital = new Hospital();
    hospital.setId(profileHospital.getHospitalId().toString());
    when(api.getHospitalController().getHospitalById(anyString())).thenReturn(ResponseEntity.ok(hospital));

    Unit unit = new Unit();
    unit.setId(profileHospital.getUnits().iterator().next().toString());
    unit.setFaxNumber("512-123-1234");
    when(api.getHospitalController().getUnitById(anyString())).thenReturn(ResponseEntity.ok(unit));

    Optional<UserDetailDTO> response = userManagement.getDetail(UserDTOUtil.getUserProfileDTO(UserRole.DSSC_OR_SCHEDULER));

    assertThat(response.isPresent()).isTrue();
    // primaryHospital is only set when the ProfileHospital has primary=true;
    // shared OR scheduler fixture may not set primary, so this block is conditional
    if (response.get().getPrimaryHospital() != null && response.get().getPrimaryHospital().getUnits() != null) {
        response.get().getPrimaryHospital().getUnits()
            .forEach(u -> assertThat(u.getFaxNumber()).isEqualTo("512-123-1234"));
    }

    assertThat(response.get().getPreference()).isNotNull();
    assertThat(response.get().getPreference().getHospitals()).isNotEmpty();
    response.get().getPreference().getHospitals().stream()
        .peek(h -> assertThat(h.getUnits()).isNotNull())
        .flatMap(h -> h.getUnits().stream())
        .forEach(u -> assertThat(u.getFaxNumber()).isEqualTo("512-123-1234"));
}
```

- If you specifically need a strict `primaryHospital.units[]` assertion, set `profileHospital.setPrimary(true)` in the test fixture before invoking `getDetail(...)`.

### 4.3 Null `faxNumber` — detail mapping does not break

```java
@Test
void getDetailOfficeSchedulerNullFaxNumberDoesNotBreak() throws ServiceException {
    UserProfile userEntity = UserDTOUtil.getUserEntity(UserRole.DSSC_OFFICE_SCHEDULER);
    assert userEntity != null;
    when(userRepository.findById(anyString())).thenReturn(Optional.of(userEntity));
    when(api.getPracticeController()).thenReturn(practiceController);

    ProfilePractice profilePractice = userEntity.getPreference().getPractices().iterator().next();
    Practice practice = new Practice();
    practice.setId(profilePractice.getPracticeId().toString());
    practice.setFaxNumber(null);  // explicitly null
    when(api.getPracticeController().getPracticeById(anyString())).thenReturn(ResponseEntity.ok(practice));

    Surgeon surgeon = new Surgeon();
    surgeon.setId(profilePractice.getSurgeons().iterator().next().toString());
    when(api.getPracticeController().getSurgeonById(anyString())).thenReturn(ResponseEntity.ok(surgeon));

    Optional<UserDetailDTO> response = userManagement.getDetail(UserDTOUtil.getUserProfileDTO(UserRole.DSSC_OFFICE_SCHEDULER));
    assertThat(response.isPresent()).isTrue();
    assertThat(response.get().getPrimaryPractice().getFaxNumber()).isNull();
}
```

---

## Step 5 — Integration Tests in `UserProfileControllerIT`

**File:** `src/test/integration/java/org/ascension/swe/surgical/userprofile/resource/UserProfileControllerIT.java`

The existing `getUserDetail()` test only asserts HTTP 200 and non-null body. Extend or add a new test to assert the JSON contract.

### 5.1 Office scheduler response includes `faxNumber` in practice objects

```java
@Test
public void getUserDetailOfficeSchedulerIncludesFaxNumber() {
    restTemplate.setRequest("/user/profile/detail", HttpMethod.GET, UserRole.DSSC_OFFICE_SCHEDULER);
    restTemplate.perform();
    assertThat(restTemplate.getStatusCode().is2xxSuccessful()).isTrue();
    UserDetailDTO body = restTemplate.getBody(UserDetailDTO.class);
    assertThat(body).isNotNull();

    assertThat(body.getPreference()).isNotNull();
    assertThat(body.getPreference().getPractices()).isNotNull();

    // primaryPractice faxNumber is nullable; assert DTO field is accessible
    PracticeDetailDTO primaryPractice = body.getPrimaryPractice();
    if (primaryPractice != null) {
        primaryPractice.getFaxNumber();
    }

    body.getPreference().getPractices().forEach(p -> p.getFaxNumber());
}
```

### 5.2 OR scheduler response includes `faxNumber` in unit objects

```java
@Test
public void getUserDetailORSchedulerIncludesFaxNumber() {
    restTemplate.setRequest("/user/profile/detail", HttpMethod.GET, UserRole.DSSC_OR_SCHEDULER);
    restTemplate.perform();
    assertThat(restTemplate.getStatusCode().is2xxSuccessful()).isTrue();
    UserDetailDTO body = restTemplate.getBody(UserDetailDTO.class);
    assertThat(body).isNotNull();

    assertThat(body.getPreference()).isNotNull();
    assertThat(body.getPreference().getHospitals()).isNotNull();

    if (body.getPrimaryHospital() != null && body.getPrimaryHospital().getUnits() != null) {
        body.getPrimaryHospital().getUnits().forEach(u -> u.getFaxNumber());
    }

    body.getPreference().getHospitals().stream()
        .peek(h -> assertThat(h.getUnits()).isNotNull())
        .flatMap(h -> h.getUnits().stream())
        .forEach(u -> u.getFaxNumber());
}
```

> **Note on integration test assertions:** The embedded MongoDB used in IT may not have seed data with `faxNumber` pre-set. The assertions above verify that the field is present and reachable on DTO objects. If seed data is extended with `faxNumber`, replace with exact value assertions.

---

## Step 6 — Build and Test

```bash
# From mit-surgical project root

# Run unit tests only for the affected service class
mvn test -Dtest=SurgicalUserAdministratorTest -DfailIfNoTests=false

# Run integration tests for the profile controller
mvn verify -Dit.test=UserProfileControllerIT -DfailIfNoTests=false

# Full build to confirm no regressions
mvn clean package -DskipTests
```

---

## Checklist

- [x] `PracticeDetailDTO.java` — `faxNumber` field added with `@Schema` annotation
- [x] `UnitDetailDTO.java` — `faxNumber` field added with `@Schema` annotation (Lombok `@Data` provides accessors)
- [x] `ModelHelper.createTypeMap()` verified — no explicit suppression of `faxNumber`
- [x] `SurgicalUserAdministratorTest` — 3 new test methods added (office fax, OR fax, null fax)
- [x] `UserProfileControllerIT` — 2 new test methods added (office IT, OR IT)
- [x] `mvn test -Dtest=SurgicalUserAdministratorTest` passes
- [ ] `mvn verify -Dit.test=UserProfileControllerIT` passes
- [ ] `mvn clean package` builds cleanly

---

## Risk / Notes

| Risk | Mitigation |
|---|---|
| OR scheduler fixture may not set `ProfileHospital.primary=true`, so `primaryHospital` can be null | Use conditional assertions for `primaryHospital`, or explicitly set primary in the test fixture when needed |
| `ModelMapper` mapping could fail only if explicit type-map suppression is introduced | Verify `ModelHelper.createTypeMap()` has no suppression for `faxNumber`; field name is identical across source/target DTOs |
| Integration seed data has no `faxNumber` in MongoDB | IT assertions are null-tolerant; upgrade to exact assertions when seed data is updated |
| Open question on null serialization not yet resolved (Q2 in spec) | Default behavior (`null` serialized as `null`) is applied; update `@JsonInclude` if product/UI decides to omit the field |
