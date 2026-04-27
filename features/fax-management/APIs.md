# Modified Existing APIs

1. dssc-document-service
- GET /v2/documents
  - Extend for Fax Inbox use cases from the Figma flows:
  - Filters: queueId, status, date range, FIN, patient name, category
  - Sort + pagination for high-volume queue views
  - Support nested metadata search (for example metadata.fin, metadata.patientLastName)

## Contract: GET /v2/documents

### Request
- Query params
  - queueId: string (optional)
  - status: string[] (optional, values: CURRENT, WAITING, REVIEWED, DATA_CONFLICTS, CLOSED)
  - fin: string (optional)
  - patientName: string (optional)
  - category: string (optional)
  - dateFrom: string (optional, ISO-8601 date-time)
  - dateTo: string (optional, ISO-8601 date-time)
  - page: number (optional, default 0)
  - size: number (optional, default 20)
  - sort: string (optional, format field,direction. Example: createdAt,desc)

### Response (200)
```json
{
  "content": [
    {
      "id": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
      "queueId": "unit-001",
      "status": "WAITING",
      "fileName": "fax-2026-04-26-001.pdf",
      "metadata": {
        "fin": "123456789",
        "patientFirstName": "JOHN",
        "patientLastName": "DOE",
        "category": "H_AND_P",
        "procedureDate": "2026-04-30"
      },
      "createdAt": "2026-04-26T14:45:10Z",
      "updatedAt": "2026-04-26T15:10:22Z"
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 1243,
  "totalPages": 63,
  "hasNext": true
}
```

# New APIs

1. dssc-document-service
- PATCH /v2/documents/{id}/metadata
  - Save manual indexing data and update fax status (WAITING/REVIEWED/DATA_CONFLICTS/CLOSED), including page classification/index info
- PUT /v2/documents/bulk-metadata
  - Bulk FIN and optional status update for selected document IDs
- GET /v2/documents/counts
  - Task-card counts by queue/status (optimized for polling; cache-backed)
- POST /v2/documents/{id}/split
  - Split multi-page PDF into child fax documents with lineage tracking
- GET /v2/documents/{id}/signed-url
  - Secure time-limited URL for print/download from viewer actions
- GET /v2/documents/{id}/activities
  - Timeline/history drawer data (who did what, when)
- PATCH /v2/documents/{id}/view-preferences
  - Persist viewer state such as rotation and flip
- GET /v2/documents/metadata-options
  - Lookup/config for dropdown options (document type/category + page type)
- GET /v2/documents/{id}/conflicts (TODO)
  - Check conflict/mismatch state on linked case; returns conflict flag, linked case, reason
- POST /v2/documents/{id}/unlink (TODO)
  - Remove incorrect case association; reverts status to REVIEWED
- POST /v2/documents/{id}/relink (TODO)
  - Re-associate document to correct case/request via FIN or requestId

## Contract: PATCH /v2/documents/{id}/metadata

### Request
- Path params
  - id: string (required)
- Body
```json
{
  "status": "REVIEWED",
  "category": "H_AND_P",
  "metadata": {
    "fin": "123456789",
    "patientFirstName": "JOHN",
    "patientLastName": "DOE",
    "dob": "1985-01-15",
    "procedureDate": "2026-04-30",
    "surgeon": "Dr. Smith",
    "cptCodes": ["47562"]
  },
  "index": [
    {
      "pageNumber": 1,
      "pageType": "COVER_SHEET"
    },
    {
      "pageNumber": 2,
      "pageType": "CLINICAL"
    }
  ]
}
```

### Response (200)
```json
{
  "id": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "status": "REVIEWED",
  "category": "H_AND_P",
  "metadata": {
    "fin": "123456789",
    "patientFirstName": "JOHN",
    "patientLastName": "DOE",
    "dob": "1985-01-15",
    "procedureDate": "2026-04-30",
    "surgeon": "Dr. Smith",
    "cptCodes": ["47562"]
  },
  "index": [
    { "pageNumber": 1, "pageType": "COVER_SHEET" },
    { "pageNumber": 2, "pageType": "CLINICAL" }
  ],
  "updatedAt": "2026-04-26T15:20:40Z",
  "updatedBy": "user-123"
}
```

## Contract: PUT /v2/documents/bulk-metadata

### Request
- Body
```json
{
  "documentIds": [
    "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
    "dc8f5c84-2f2c-4ff0-a2ec-6c0be7f7eb8a"
  ],
  "metadata": {
    "fin": "123456789"
  },
  "status": "REVIEWED"
}
```

### Response (200)
```json
{
  "updatedCount": 2,
  "failedIds": [],
  "updatedAt": "2026-04-26T15:25:11Z"
}
```

## Contract: GET /v2/documents/counts

### Request
- Query params
  - queueIds: string[] (optional)
  - statuses: string[] (optional, values: CURRENT, WAITING, REVIEWED, DATA_CONFLICTS, CLOSED)

### Notes
- `CURRENT` is a menu/status bucket and should be computed as `WAITING + REVIEWED`.

### Response (200)
```json
{
  "generatedAt": "2026-04-26T15:30:00Z",
  "ttlSeconds": 60,
  "countsByQueue": [
    {
      "queueId": "unit-001",
      "counts": {
        "CURRENT": 46,
        "WAITING": 34,
        "REVIEWED": 12,
        "DATA_CONFLICTS": 3,
        "CLOSED": 220
      },
      "total": 269
    }
  ]
}
```

## Contract: POST /v2/documents/{id}/split

### Request
- Path params
  - id: string (required)
- Body
```json
{
  "children": [
    {
      "name": "child-1",
      "pageRanges": [
        { "from": 1, "to": 2 }
      ],
      "metadata": {
        "fin": "123456789",
        "category": "H_AND_P"
      }
    },
    {
      "name": "child-2",
      "pageRanges": [
        { "from": 3, "to": 5 }
      ]
    }
  ]
}
```

### Response (201)
```json
{
  "parentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "parentStatus": "CLOSED",
  "childDocumentIds": [
    "5f8d9d20-9b77-4fef-a289-6d4c54a2fe0d",
    "6efb6282-55db-4d4e-9efd-f15fba4f4f41"
  ],
  "createdCount": 2
}
```

## Contract: GET /v2/documents/{id}/signed-url

### Request
- Path params
  - id: string (required)
- Query params
  - action: string (optional, values: VIEW, DOWNLOAD, PRINT; default VIEW)

### Response (200)
```json
{
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "signedUrl": "https://storage.googleapis.com/...",
  "expiresAt": "2026-04-26T15:41:00Z",
  "action": "DOWNLOAD"
}
```

## Contract: GET /v2/documents/{id}/activities

### Request
- Path params
  - id: string (required)
- Query params
  - page: number (optional, default 0)
  - size: number (optional, default 20)
  - actionType: string (optional, filter by action. Values: INGESTED, INDEXED, METADATA_UPDATED, STATUS_CHANGED, SPLIT, LINKED, BULK_UPDATED, VIEWED)
  - sortOrder: string (optional, values: asc, desc; default desc for reverse chronological)

### Notes
- All activity records are immutable once created; timestamps use UTC ISO-8601.
- `before` and `after` contain the state of changed fields only (not entire document).
- `actorType` distinguishes user-initiated from system-initiated actions for compliance.
- For SPLIT: `splitDetails` shows parent/child relationships and page ranges.
- For LINKED: `linkDetails` shows the target request/case association.
- For BULK_UPDATED: `bulkDetails` shows batch operation context and count.

### Response (200)
```json
{
  "content": [
    {
      "activityId": "a8f79317-1d89-4f15-aec4-c59088efecb2",
      "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
      "action": "METADATA_UPDATED",
      "actionCategory": "USER_EDIT",
      "actorId": "user-123",
      "actorName": "Uneedra Lewis",
      "actorType": "USER",
      "timestamp": "2026-04-26T15:20:40Z",
      "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
      "ministry": "ASMCA",
      "queueId": "unit-001",
      "changes": [
        {
          "field": "status",
          "before": "WAITING",
          "after": "REVIEWED",
          "dataType": "string"
        },
        {
          "field": "metadata.fin",
          "before": null,
          "after": "123456789",
          "dataType": "string"
        },
        {
          "field": "metadata.patientLastName",
          "before": null,
          "after": "DOE",
          "dataType": "string"
        }
      ],
      "metadata": {
        "ipAddress": "192.168.1.100",
        "userAgent": "Mozilla/5.0...",
        "source": "UI_FAXMANAGEMENT"
      }
    },
    {
      "activityId": "b9g08428-2f90-5g16-bfd5-d60099ffedc3",
      "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
      "action": "STATUS_CHANGED",
      "actionCategory": "SYSTEM_AUTO",
      "actorId": "system-link-service",
      "actorName": "Auto-Link Service",
      "actorType": "SYSTEM",
      "timestamp": "2026-04-26T15:21:15Z",
      "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4737-00f067aa0ba902b8-01",
      "ministry": "ASMCA",
      "queueId": "unit-001",
      "changes": [
        {
          "field": "status",
          "before": "REVIEWED",
          "after": "CLOSED",
          "dataType": "string"
        }
      ],
      "linkDetails": {
        "requestId": "req-001",
        "caseId": "case-123",
        "linkMethod": "FIN_AUTO_MATCH",
        "confidence": 0.95
      },
      "metadata": {
        "source": "BACKEND_SERVICE"
      }
    },
    {
      "activityId": "c7h19539-3g01-6h27-cge6-e71100ggfed4",
      "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
      "action": "SPLIT",
      "actionCategory": "USER_EDIT",
      "actorId": "user-456",
      "actorName": "Jane Smith",
      "actorType": "USER",
      "timestamp": "2026-04-26T14:55:00Z",
      "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4738-00f067aa0ba902b9-01",
      "ministry": "ASMCA",
      "queueId": "unit-001",
      "changes": [
        {
          "field": "status",
          "before": "REVIEWED",
          "after": "CLOSED",
          "dataType": "string"
        },
        {
          "field": "metadata.splitIndicator",
          "before": false,
          "after": true,
          "dataType": "boolean"
        }
      ],
      "splitDetails": {
        "parentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
        "childDocumentIds": [
          "5f8d9d20-9b77-4fef-a289-6d4c54a2fe0d",
          "6efb6282-55db-4d4e-9efd-f15fba4f4f41"
        ],
        "splits": [
          {
            "childId": "5f8d9d20-9b77-4fef-a289-6d4c54a2fe0d",
            "pageRanges": [{ "from": 1, "to": 2 }]
          },
          {
            "childId": "6efb6282-55db-4d4e-9efd-f15fba4f4f41",
            "pageRanges": [{ "from": 3, "to": 5 }]
          }
        ]
      },
      "metadata": {
        "ipAddress": "192.168.1.101",
        "source": "UI_FAXMANAGEMENT"
      }
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 14,
  "totalPages": 1,
  "hasNext": false
}

## Contract: PATCH /v2/documents/{id}/view-preferences

### Request
- Path params
  - id: string (required)
- Body
```json
{
  "viewPreferences": {
    "rotationAngle": 90,
    "isFlipped": false
  }
}
```

### Response (200)
```json
{
  "id": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "viewPreferences": {
    "rotationAngle": 90,
    "isFlipped": false
  },
  "updatedAt": "2026-04-26T15:42:20Z",
  "updatedBy": "user-123"
}
```

## Contract: GET /v2/documents/metadata-options

### Request
- Query params
  - ministry: string (optional)
  - queueId: string (optional)
  - includeInactive: boolean (optional, default false)

### Notes
- `documentTypes` are document-level classifications (one value per fax/document).
- `pageTypes` are page-level classifications used by indexing/pagination tab (per page entry in `index[]`).
- Canonical option values are TBD and must come from Product/BA approved configuration source-of-truth.

### Response (200)
```json
{
  "documentTypes": [
    {
      "code": "<TBD_DOCUMENT_TYPE_CODE>",
      "label": "<TBD Document Type Label>",
      "active": true,
      "sortOrder": 1
    }
  ],
  "pageTypes": [
    {
      "code": "<TBD_PAGE_TYPE_CODE>",
      "label": "<TBD Page Type Label>",
      "active": true,
      "sortOrder": 1
    }
  ],
  "source": "PRODUCT_CONFIG",
  "lastUpdatedAt": "2026-04-26T16:05:00Z"
}
```

## Contract: GET /v2/documents/{id}/conflicts (TODO)

### Request
- Path params
  - id: string (required)

### Response (200) - TODO: Define conflict detection strategy and payload structure
```json
{
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "hasConflict": true,
  "conflictReason": "FIN_MISMATCH",
  "linkedRequestId": "req-001",
  "linkedCaseId": "case-123",
  "conflictDetails": "TODO: Conflict detection logic and mismatch details",
  "suggestedActions": ["UNLINK", "RELINK", "UPDATE_FIN"],
  "detectedAt": "2026-04-26T15:21:15Z"
}
```

### Notes - TODO: Clarify
- Who/what detects conflicts? (automatic system validation or manual user flag?)
- What status should conflicted docs have? (Add new CONFLICT enum value?)
- Can conflict be self-resolved or requires admin intervention?

## Contract: POST /v2/documents/{id}/unlink (TODO)

### Request
- Path params
  - id: string (required)
- Body (TODO: Define request structure)
```json
{
  "reason": "INCORRECT_CASE",
  "notes": "Optional notes for audit trail"
}
```

### Response (200) - TODO: Define unlink outcome
```json
{
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "previousRequestId": "req-001",
  "newStatus": "REVIEWED",
  "unlinkedAt": "2026-04-26T15:25:00Z",
  "unlinkedBy": "user-123"
}
```

### Notes - TODO: Clarify
- Should unlink also remove from mit-surgical attachments?
- Revert to REVIEWED or different status?
- Can unlink be atomic with relink or separate ops?

## Contract: POST /v2/documents/{id}/relink (TODO)

### Request
- Path params
  - id: string (required)
- Body (TODO: Define request structure - FIN vs requestId vs manual selection)
```json
{
  "linkMethod": "FIN_AUTO_MATCH | REQUEST_ID_DIRECT | MANUAL_SELECTION",
  "requestId": "req-002",
  "fin": "987654321",
  "reason": "CORRECTING_PREVIOUS_MISMATCH"
}
```

### Response (201) - TODO: Define relink outcome
```json
{
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "previousRequestId": "req-001",
  "newRequestId": "req-002",
  "newStatus": "CLOSED",
  "relinkedAt": "2026-04-26T15:26:00Z",
  "relinkedBy": "user-123",
  "linkDetails": {
    "linkMethod": "FIN_AUTO_MATCH",
    "confidence": 0.98
  }
}
```

### Notes - TODO: Clarify
- Should relink validate against mit-surgical before accepting?
- Any conflict between FIN and requestId provided?
- Does relink auto-trigger update in mit-surgical or deferred?
- Require admin approval or user self-service?

2. mit-surgical
- No mandatory new endpoint identified from current scope
- If missing today, add/extend attachment-linking API support to reliably associate closed fax documents to surgery requests (requestId + document reference)

## Contract Note: mit-surgical attachment linking (if enhancement is needed)

### Candidate request
```json
{
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "fileName": "fax-2026-04-26-001.pdf",
  "attachmentType": "FAX",
  "source": "dssc-document-service"
}
```

### Candidate response (200/201)
```json
{
  "requestId": "req-001",
  "attachmentId": "att-987",
  "documentId": "f3b8f2cc-4b8a-4f0e-8e79-3f6733f6f2a5",
  "linkedAt": "2026-04-26T15:45:00Z"
}
```