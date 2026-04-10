# Java 21 Coding Standards

## Language Features

- Use **records** for immutable data carriers (DTOs, value objects)
- Use **sealed interfaces/classes** for restricted type hierarchies
- Use **pattern matching** for `instanceof` checks
- Use **text blocks** for multi-line strings (SQL, JSON templates)
- Use **switch expressions** with pattern matching where applicable

## General Conventions

- Prefer immutable collections (`List.of()`, `Map.of()`)
- Use `Optional` for return types that may be absent; never for fields or parameters
- Prefer `var` for local variables when the type is obvious from the RHS
- Use `Stream` operations over imperative loops for collection transformations

## Spring Boot Conventions

- Use constructor injection (no `@Autowired` on fields)
- Use `@ConfigurationProperties` over `@Value` for grouped configuration
- Profile-based configuration: `application.yml`, `application-cloud.yml`, `application-local.yml`

<!-- TODO: Add more team-specific conventions -->
