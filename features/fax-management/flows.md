## Fax Management Flows

### Happy Flow: Fax received -> indexed -> linked -> closed

1. Inbound fax is deposited by RightFax into storage.
2. Cloud Function parses metadata (ministry, sender/receiver fax) and forwards document metadata to document processing.
3. Document is created in Fax Management with status **Waiting**.
4. OR Scheduler opens the fax from queue, reviews PDF, and indexes metadata (for example: document type, patient fields, FIN).
5. Status moves to **Reviewed** after metadata save.
6. System resolves FIN and links document to matching Cerner-related case/request in mit-surgical.
7. Status moves to **Closed** after successful case association.
8. Activity timeline records both user and system actions (including final linkage transition).

### Unhappy Flow: Wrong FIN causes wrong case association (conflict + correction)

1. Inbound fax is received and shown in **Waiting**.
2. Scheduler indexes fax and enters FIN.
3. FIN is incorrect (or maps ambiguously), causing incorrect case association.
4. Conflict/warning indicators appear in list/detail contexts (or mismatch discovered during review).
5. Scheduler/Admin investigates in processed/closed view and identifies incorrect linkage.
6. Scheduler/Admin performs correction workflow (unlink/relink/update FIN, depending on final API design).
7. System re-associates fax to correct case and updates status accordingly.
8. Activity timeline captures full before/after corrections for audit and compliance.

### Key requirements implied by these 2 flows

- Separate metadata completion state from Cerner-link completion state.
- Conflict flags and correction actions must be first-class.
- Full field-level audit history is required for recoverability and compliance.
- Monitoring should track mismatch/conflict rate and correction turnaround time.