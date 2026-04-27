# Case List Page API Map

## Overview

The Case List page is a composed experience. It combines:
- mit-surgical case list and case status APIs
- mit-surgical hospital/unit master data APIs
- dssc-document-service fax task-card count APIs
- dssc-document-service fax list APIs
- mit-surgical case attachment linking for closed faxes

The UI should merge `queueId` from dssc-document-service with `unitId` from mit-surgical to render queue labels and task cards correctly.

## Existing APIs reused by Case List page

### 1. Load case list
- Service: `mit-surgical`
- Endpoint: `GET /surgery/schedule/`
- Purpose: Load case list / case cards for the page.

### 2. Search or filter case list
- Service: `mit-surgical`
- Endpoint: `POST /surgery/schedule/search`
- Purpose: Search/filter the case list using request-body criteria.

### 3. Load case status summary
- Service: `mit-surgical`
- Endpoint: `GET /surgery/schedule/status/`
- Purpose: Load case-side status summary used by case cards.

### 4. Load case details
- Service: `mit-surgical`
- Endpoint: `GET /surgery/schedule/{requestId}`
- Purpose: Load the selected case details.

### 5. Load hospitals
- Service: `mit-surgical`
- Endpoint: `GET /hospital` or `GET /hospitals`
- Purpose: Load hospital master data for Case List context.

### 6. Load units available to current user
- Service: `mit-surgical`
- Endpoint: `GET /hospital/user/unit/`
- Purpose: Load units/queues available to the current user.

### 7. Resolve unit by id
- Service: `mit-surgical`
- Endpoint: `GET /hospital/unit/{id}`
- Purpose: Resolve queue/unit display details.

### 8. Resolve unit by name
- Service: `mit-surgical`
- Endpoint: `GET /hospital/unit?name={name}`
- Purpose: Optional unit lookup by name.

## New or dependent APIs used by fax task cards on Case List page

### 1. Load fax task-card counts
- Service: `dssc-document-service`
- Endpoint: `GET /v2/documents/counts`
- Purpose: Load fax task-card counts by queue/status.
- Notes:
  - Client merges `queueId` with mit-surgical unit data.
  - Statuses currently expected: `CURRENT`, `WAITING`, `REVIEWED`, `DATA_CONFLICTS`, `CLOSED`.

### 2. Load fax list after selecting task card
- Service: `dssc-document-service`
- Endpoint: `GET /v2/documents`
- Purpose: Load fax list after user selects a task card or applies fax filters.

## Cross-service case-linking dependency

### 1. Attach closed fax to case
- Service: `mit-surgical`
- Endpoint: `POST /v2/surgery-requests/{requestId}/attachments`
- Purpose: Attach a closed fax document to the selected surgery request.
- Status: Referenced by fax-management backend spec; confirm final controller contract if this should become a fully contracted section.

## Client-side merge behavior

- The page should fetch case data from `mit-surgical`.
- The page should fetch fax task-card counts from `dssc-document-service`.
- The page should cross-reference `queueId` from document service with `unitId` from mit-surgical.
- This page is a multi-service UI composition, not a single-service page.

## Source References

### PRD
- `Case list Task card`
- Source: `features/fax-management/Fax-Management-PRD.md`

### Backend technical specification
- Task cards per Unit/Queue
- Client-side merge of queue descriptions from mit-surgical with counts from dssc-document-service
- Source: `features/fax-management/Backend-Technical-Specification-TXAUS-Fax-Management.md`

### Verified mit-surgical controller contracts
- `SurgeryRequestContract.java`
- `HospitalContract.java`