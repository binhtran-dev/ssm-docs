# Database Entity Pattern

## MongoDB Document Design

### Entity Base

All MongoDB documents should include:
```java
@Document(collection = "collectionName")
@Data
@Builder
public class MyEntity {
    @Id
    private String id;
    
    private Instant createdAt;
    private Instant updatedAt;
    private String createdBy;
    private String updatedBy;
}
```

### Conventions

- Use `@Document` annotation with explicit collection name
- Use `String` for `@Id` fields (MongoDB ObjectId as string)
- Include audit fields (`createdAt`, `updatedAt`, `createdBy`, `updatedBy`)
- Use `Instant` for all date/time fields
- Embed related data when it's always read together; reference when independent

### Indexing

- Always define indexes for query patterns (use `@Indexed` or `@CompoundIndex`)
- Document index decisions in the entity class as comments

<!-- TODO: Add examples from actual services -->
