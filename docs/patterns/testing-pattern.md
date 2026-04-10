# Testing Pattern

## Test Pyramid

```
    /  E2E  \        — Few: Full stack with emulators (dev-local)
   /  Integ  \       — Some: Spring context + embedded MongoDB
  /   Unit    \      — Many: Plain JUnit 5 + Mockito
```

## Unit Tests

- Use **JUnit 5** with **Mockito**
- Test service layer logic in isolation
- Mock repositories and external clients
- Use `@ExtendWith(MockitoExtension.class)`

```java
@ExtendWith(MockitoExtension.class)
class MyServiceTest {
    @Mock
    private MyRepository repository;
    
    @InjectMocks
    private MyService service;
    
    @Test
    void shouldDoSomething() {
        // given
        when(repository.findById("1")).thenReturn(Optional.of(entity));
        // when
        var result = service.process("1");
        // then
        assertThat(result).isNotNull();
    }
}
```

## Integration Tests

- Use `@SpringBootTest` with embedded MongoDB (`de.flapdoodle.embed.mongo`)
- Test repository queries and Spring context wiring
- Use `@DirtiesContext` sparingly

## E2E Tests (Local)

- Use dev-local Docker Compose stack
- Test full flows including Pub/Sub messaging and GCS interactions
- Run via `dev-local/scripts/start.sh`

## Naming Convention

- `*Test.java` — Unit tests
- `*IntegrationTest.java` — Integration tests
- `*E2ETest.java` — End-to-end tests

<!-- TODO: Add test data builder patterns, fixtures strategy -->
