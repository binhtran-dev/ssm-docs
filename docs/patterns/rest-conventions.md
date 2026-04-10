# REST Conventions

## URL Structure

```
GET    /api/{resource}             — List (paginated)
GET    /api/{resource}/{id}        — Get by ID
POST   /api/{resource}             — Create
PUT    /api/{resource}/{id}        — Full update
PATCH  /api/{resource}/{id}        — Partial update
DELETE /api/{resource}/{id}        — Delete
```

## Naming

- Use **kebab-case** for URL paths: `/api/block-times`, `/api/surgery-requests`
- Use **camelCase** for JSON field names
- Use plural nouns for resource collections

## Response Codes

| Code | Usage |
|------|-------|
| 200 | Successful GET, PUT, PATCH |
| 201 | Successful POST (Created) |
| 204 | Successful DELETE (No Content) |
| 400 | Validation error |
| 401 | Unauthenticated |
| 403 | Unauthorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate, version mismatch) |
| 500 | Internal server error |

## Pagination

```json
{
  "content": [...],
  "page": 0,
  "size": 20,
  "totalElements": 100,
  "totalPages": 5
}
```

## Error Response

```json
{
  "timestamp": "2026-04-10T12:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "details": [
    { "field": "name", "message": "must not be blank" }
  ]
}
```

<!-- TODO: Add versioning strategy, HATEOAS decision -->
