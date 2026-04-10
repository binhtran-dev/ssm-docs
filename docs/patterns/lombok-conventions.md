# Lombok Conventions

## Approved Annotations

| Annotation | Use Case | Notes |
|-----------|----------|-------|
| `@Data` | Mutable entities/POJOs | Generates getters, setters, equals, hashCode, toString |
| `@Builder` | Object construction | Use for objects with many fields |
| `@Slf4j` | Logging | Standard logger in all classes |
| `@RequiredArgsConstructor` | DI constructors | Use with `final` fields for Spring DI |
| `@Value` (Lombok) | Immutable DTOs | Consider Java records instead for new code |
| `@Getter` / `@Setter` | Selective access | When `@Data` is too broad |

## Avoid

- `@AllArgsConstructor` — Use `@Builder` or `@RequiredArgsConstructor` instead
- `@ToString` with lazy collections — Can trigger N+1 queries
- `@EqualsAndHashCode` on entities with database IDs — Override manually

## Migration Path

For new code, prefer **Java records** over Lombok `@Value` for immutable DTOs.

<!-- TODO: Add examples and anti-patterns -->
