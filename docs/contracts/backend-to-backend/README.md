# Backend-to-Backend Contracts

## Pub/Sub Message Schemas

Define the message format for each Pub/Sub topic used for inter-service communication.

### Cross-Service Message Flows

| From | Topic | To | Description |
|------|-------|----|-------------|
| document-service | `document.scan.local` | upload-handler/clamav | Scan request |
| document-service | `document.status.local` | mit-surgical | Document status update |
| upload-handler | `virusscan.result.*` | document-service | Virus scan result |
| mit-surgical | `ssm.surgeryrequest.local` | block-time-service | Surgery request |
| mit-surgical | `ssm.notification.local` | consumers | Notification event |
| block-time-service | `dssc.email.local` | email handler | Email notification |
| multiple | `metrics.event.local` | monitoring | Metrics event |
| multiple | `ssm.compliance-logging.local` | compliance | Audit log |

<!-- TODO: Add JSON schemas for each Pub/Sub message type -->
