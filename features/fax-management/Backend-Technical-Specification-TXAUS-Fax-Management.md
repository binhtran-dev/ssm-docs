# **Backend Technical Specification: TXAUS Fax Management**

**Affected Microservices:** dssc-document-service (Main), mit-surgical (Read-only/Linking)

**Technologies:** Java 17+, Spring Boot, MongoDB, Google Cloud Platform (GCS, Pub/Sub, Cloud Functions), Apache PDFBox.

**Figma Design:** https://www.figma.com/design/fTavnSI8sRCw1EfXVYpU7G/Fax-Management?node-id=971-14724\&p=f\&m=dev 

## **1\. Architecture Overview**

The goal is to replace ActiveFax by ingesting documents from RightFax directly into Google Cloud Storage (GCS). By removing AI extraction (UiPath) from the initial scope, the workflow will rely on **manual indexing** by the *OR Schedulers*, leaning on the mit-surgical clinical database for auto-completion and cross-validation via the account number (FIN Number) and the hospital's Units structure.

### **Data Flow:**

1. **RightFax** deposits the file in GCS: /{ministry}/{receiverFaxNumber}/{senderFaxNumber}/yyyy-mm-dd/{fileName}.pdf.  
2. **Cloud Function** is triggered by the GCS event, extracts the fax number from the *path*, and emits an event to **Pub/Sub**.  
3. **Document Service** consumes the event, infers the base Unit/Hospital, and creates an initial DocumentEntity in MongoDB (Status: WAITING).  
4. **UI (Frontend)** lists pending faxes by cross-referencing unit information with mit-surgical. The user views the PDF and visually extracts the data.  
5. Upon entering the FIN, the Frontend queries **mit-surgical** to fetch the patient and case details.  
6. The user saves, closing the fax in the **Document Service** and linking it as a physical *Attachment* in the SurgeryRequest within **mit-surgical**.

## **2\. Data Modeling (MongoDB)**

To ensure optimal performance and to apply the existing Search Service pattern from mit-surgical, a **Hybrid** data model will be used.

* **Root Fields (Core System Fields):** Attributes such as id, queueId (Mapped directly to the mit-surgical **Unit** ID), status (WAITING, REVIEWED, CLOSED), and base audit fields (createdAt) will be kept at the root of the DocumentEntity.  
* **Nested Object (MetadataDTO):** All data manually entered or visually extracted by the user (fin, patientFirstName, patientLastName, procedureDate, cptCodes, category) will be grouped within an embedded object named metadata. This keeps the root clean and allows this entire block to be sent as a single DTO through the API.  
* **Index Object (Pagination Tab):** A sub-object index will control the visual page classification for the UI.

## **3\. Task Breakdown (Epics & User Stories)**

### **Epic 1: RightFax Ingestion via Cloud Function**

*Adapting the inbound flow from GCS to the Document Service.*

* **Story 1.1: GCS Cloud Function Refactor**  
  * **Description:** Modify the existing ActiveFax Cloud Function to process PDFs from the new RightFax path. The function must parse the file *path* (/txaus/{faxnumber}/...) to extract the ministry and the receiving fax number.  
  * **Technical:** Build a standard JSON payload to notify Pub/Sub.  
  * **Estimate: X Pts.**   
* **Story 1.2: Fax Routing to Unit (Routing Engine)**  
  * **Description:** Implement a mapping dictionary in the Document Service to translate the incoming fax number to a valid Unit ID (queueId) existing in mit-surgical (e.g., MC Main OR).  
  * **Technical:** Create a MongoDB collection FaxRoutingConfig. Save the initial DocumentEntity assigning the root field queueId and status: WAITING.  
  * **Estimate: X Pts.**

### **Epic 2: Fax Management Core API & Indexing (Integration)**

*Endpoints to list, filter, and manually save metadata, cross-referencing data with the surgical domain.*

* **Story 2.1: Inbox Search and Filtering using Search Service**  
  * **Description:** Optimize the fax list to support the inbox UI with thousands of records in CLOSED and WAITING statuses.  
  * **Technical:** Update GET /v2/documents (or equivalent). Implement and reuse the SearchQueryBuilder pattern from mit-surgical. Adapt the *Criteria queries* to search nested fields using dot notation (e.g., metadata.fin, metadata.patientLastName). Keep exact field searches (queueId, status) at the root. Create indexes in MongoDB (e.g., { "queueId": 1, "status": 1 }, { "metadata.fin": 1 }).  
  * Create a separate ticket for adding Atlas Search Index in MongoDB  
  * **Estimate: X Pts.5**  
* **Story 2.2: Metadata, Indexing, and Fax Closure Endpoint**  
  * **Description:** Allow saving the manual data extracted by the user (Category, FIN, Procedure) in the corresponding DTO, define the page type (*pagination tab*), and change the Fax status.  
  * **Technical:** **Create** the endpoint PATCH /v2/documents/{id}/metadata. The payload must receive the MetadataDTO object to inject it into the metadata sub-document (without validating it against Cerner). Also include the index field that determines the page type (indexing or pagination tab). Change the root status field to REVIEWED or CLOSED as appropriate.  
  * **Estimate: X Pts.3**  
* **Story 2.3: Official Case Linking (Cross-Service)**  
  * **Description:** Integrate the Fax closure with the main attachments system.  
  * **Technical:** Support the frontend to ensure that, upon closing the fax, the POST /v2/surgery-requests/{requestId}/attachments endpoint from **mit-surgical** is reused, passing the GCS document ID so it is displayed in the main clinical platform.  
  * Notes: once use enter FIN, then link it with the request if it exists, if not the request will be updated once created. Try to unify the endpoint in 2.4  
  * **Estimate: X Pts.3**  
* **Story 2.4: Mass Update (Bulk FIN Update)**  
  * **Description:** Apply the same FIN Number to multiple document UUIDs with a single click.  
  * **Technical:** Create PUT /v2/documents/bulk-metadata. Use BulkOperations in Spring Data Mongo for an atomic update of the metadata.fin and status fields across multiple records simultaneously.  
  * **Estimate: X Pts.3**  
* **Story 2.5: Reuse of Units Endpoints (mit-surgical) for Queues**  
  * **Description:** For the UI to populate the "Queues" dropdown menus and show the actual clinic description, it must consume the master service instead of duplicating data.  
  * **Technical:** The Backend team will document for the Frontend the use of the existing endpoints of the Unit entity (e.g., UnitController in mit-surgical) to get the list of units. In the Document Service, queueId will correspond to this unitId.  
  * Notes: update Data Provision to include new required information \- Create another ticket   
  * **Estimate:** X Pt.6 *(Mainly analysis and documentation for Frontend)*  
* **Story 2.6: Aggregation Endpoint for Task Cards (Counts with Cache)**  
  * **Description:** The user interface shows "Task Cards" per Unit/Queue with the exact number of pending faxes. Making individual HTTP queries for each unit (and via UI *polling*) would crash the database.  
  * **Technical:** **Create** a new endpoint in Document Service GET /v2/documents/counts (or /summary). Build an aggregation pipeline in MongoDB (MongoTemplate.aggregate(...)) that groups using $group by the queueId field and counts the faxes based on their status (especially WAITING). **Critical:** Implement a caching layer (e.g., Spring @Cacheable with Redis, similar to mit-surgical) with a short TTL (Time To Live) (e.g., 30-60 seconds) to protect MongoDB from intensive UI *polling*. Return a consolidated JSON that the UI can cross-reference with the info obtained in Story 2.5.  
  * Notes: Create new endpoint for the Fax count  
  * **Estimate: X Pts.3**

### **Epic 3: PDF Manipulation and Visualization (Server-Side)**

*Support for the frontend viewer tool panel (Figma).*

* **Story 3.1: Rotation and Flip Metadata (Rotate/Flip)**  
  * **Description:** Allow the user to rotate or mirror the document on the screen without modifying the underlying physical file.  
  * **Technical:** Add rotationAngle (number) and isFlipped (boolean) attributes to the DocumentEntity (they can live inside a viewPreferences object). Expose them and allow them to be updated via API.  
  * Notes: new endpoint to update the file configuration upon receiving from UI  
  * **Estimate: X Pts.8**  
* **Story 3.2: Split Document Engine**  
  * **Description:** Implement the logic to divide a PDF (containing faxes from multiple patients) into individual files.  
  * **Technical:** Create POST /v2/documents/{id}/split. Download the PDF from GCS into memory using **Apache PDFBox**, separate the pages indicated in the payload, and upload the *new* PDFs to GCS. Save the new ones in MongoDB as WAITING. Mark the original parent document as CLOSED (maintaining traceability splitParent: true).  
  * **Estimate:** X Pts.8  
* **Story 3.3: Secure GCS Proxy (Print / Download)**  
  * **Description:** Facilitate printing and downloading without opening the bucket to the public.  
  * **Technical:** Create GET /v2/documents/{id}/signed-url. Generate a signed Google Cloud Storage URL with a 5-10 minute expiration.  
  * **Estimate: X Pts.**

### **Epic 4: Activity Log and Audit Trail**

*Support for the UI right panel (History of actions on the fax).*

* **Story 4.1: Audit Persistence Model**  
  * **Description:** Track who, when, and what action was performed on each document.  
  * **Technical:** Create a DocumentActivityEntity collection. Implement Spring AOP (Aspects) in dssc-document-service to intercept modification calls (Split, Metadata Update, Status Change) and asynchronously insert the logs (e.g., User "Uneedra Lewis" performed action "INDEXED" at 2:49 PM).  
  * **Estimate: X Pts.10**  
* **Story 4.2: Timeline Endpoint**  
  * **Description:** Expose the activity history for the UI Drawer.  
  * **Technical:** Create GET /v2/documents/{id}/activities sorted by timestamp: \-1.  
  * **Estimate: X Pts.10**

## **4\. Effort Summary**

| Epic | Description | Estimated Story Points |
| :---- | :---- | :---- |
| **Epic 1** | Event-Driven Ingestion (Cloud Function) | 12 Pts |
| **Epic 2** | Core API, MetadataDTO & UI Integration (Task Cards) | 23 Pts |
| **Epic 3** | PDF Manipulation (PDFBox & GCS URLs) | 16 Pts |
| **Epic 4** | Document Activity / Audit Trail | 20 Pts |
| **TOTAL** |  | **71 Story Points** |

**Additional Notes for the Team:**

* **UI Integration:** The interface must perform a logical *Merge* on the client side. It will fetch the description of the queues (Units) from mit-surgical and cross-reference it with the counts and IDs (queueId) coming from the dssc-document-service to render the selectors and Task Cards efficiently.  
* **Advanced Search:** The Search Service pattern from mit-surgical will be applied over the nested metadata object for efficient searches in MongoDB.  
* **Domain Separation:** dssc-document-service is purely a file handler, storage for MetadataDTO, and *pagination tabs* (index). All clinical logic and final status of the procedure reside in mit-surgical.