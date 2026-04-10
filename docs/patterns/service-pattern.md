# Service Pattern

## Layered Architecture

```
Controller → Service → Repository
    ↓           ↓
   DTO        Entity
```

### Controller Layer
- Handles HTTP request/response mapping
- Input validation via `@Valid`
- Maps DTOs to/from service layer
- No business logic

### Service Layer
- Contains business logic
- Transaction boundaries
- Publishes domain events (Pub/Sub)
- Uses repository for data access

### Repository Layer
- Spring Data MongoDB repositories
- Custom queries via `@Query` or `MongoTemplate`
- No business logic

## DTO vs Entity Separation

- **Entity**: MongoDB document, annotated with `@Document`
- **Request DTO**: Incoming API payload, annotated with validation constraints
- **Response DTO**: Outgoing API payload, may differ from entity
- Use MapStruct or manual mapping between layers

## Pub/Sub Publisher Pattern

```java
@RequiredArgsConstructor
@Service
public class MyPublisher {
    private final PubSubTemplate pubSubTemplate;
    
    @Value("${message.my.topic}")
    private String topicName;
    
    public void publish(MyEvent event) {
        pubSubTemplate.publish(topicName, event);
    }
}
```

<!-- TODO: Add subscriber/listener pattern -->
