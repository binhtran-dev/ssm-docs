**Fax Management PRD**

**Date: 3/11/26**

---

## **Summary**

## To reduce workload on the TXAUS ministries OR Schedulers and provide them a single application from which to manage faxes and schedule cases, SSM plans to integrate with RightFax to bring inbound faxes into SSM. The solution will allow OR Schedulers to identify boarding sheets within the scheduling queue automatically sending the boarding sheet to be processed by AI which will provide key data elements related to scheduling cases into Cerner. The OR Schedulers are then able to manipulate documents while tracking and viewing activity of the document.  This will significantly reduce manual effort, eliminate parallel systems, and improve adoption of SSM for surgical scheduling workflows.

## ---

## **Goals & Impact**

### **Business Goals**

* ## Enable TXAUS ministries to fully leverage SSM as the single system of record for case scheduling 

* ## Reduce operational cost and manual effort associated with fax management 

* ## Increase adoption and consistent use of SSM across the TXAUS ministry 

* ## Improve scheduling efficiency and accuracy through automated document case data extraction 

  ### **User Goals**

* ## OR Scheduler can access both unscheduled cases and inbound faxes within SSM 

* ## Reduce manual data entry required to index faxed documents 

* ## Eliminate the need to work in both ActiveFax and SSM 

* ## Quickly identify boarding sheets and extract scheduling data using AI

* ## Visualize and track document changes based on user activity

* ## OR Schedulers are able to manipulate documents 

## ---

## **Narrative**

### **Problem Statement**

## OR Schedulers find that SSM does not currently provide sufficient value due to the need to operate in two parallel systems: ActiveFax for fax management and SSM for scheduling. This split workflow increases cognitive load, duplicative effort, and overall inefficiency, while limiting the perceived benefits of SSM.

### **Impact**

## This results in low adoption rates, increased scheduler frustration, and a risk of failure to deploy SSM successfully across TXAUS ministries.

## ---

## **User Stories**

* ## As an OR Scheduler, I want to view and manage all inbound faxes directly in SSM so I don’t have to switch systems. 

* ## As an OR Scheduler, I want boarding sheets to be automatically identified so I can focus on scheduling rather than sorting documents. 

* ## As an OR Scheduler, I want key information to be extracted via AI to reduce scheduling time  

* ## As an OR Scheduler, I want to link non-boarding sheet faxes to existing cases so documentation stays complete and accurate.

* ## As an OR Scheduler, I want to be able to index support documents that do not have a case yet

* ## As an OR Scheduler I want to be able to search for previously processed documents 

* ## As an OR scheduler I want to be able to find completed faxes that have been linked to a case

* ## As an OR scheduler I want to be able to update the FIN to multiple documents

* ## As the OR Scheduler I should not have SSM automatically find and associate documents to a case via Fin number upon reaching SSM from Cerner

* ## As the OR Scheduler I should be able to index the document based on documentary type and pages

* ## As the OR Scheduler Admin I should be able to see all activity for a document 

* ## As the OR Scheduler all the fax meta data should be displayed once a case is linked to a case 

## ---

## **Proposed User Workflow** 

## **Lucid Workflow \-**  [Workflow](https://lucid.app/lucidchart/4ee250a2-f075-4c7a-add9-7e132ef05bad/edit?viewport_loc=2937%2C170%2C5513%2C2770%2C0_0&invitationId=inv_62749533-a7c7-45fa-b1a9-d2bc3ac5caf8)

## **Design Reference/Annotations:** [Figma](https://www.figma.com/design/fTavnSI8sRCw1EfXVYpU7G/Fax-Management?node-id=971-14724&p=f&t=9cT3V3BGl7duffU8-0)

**Design Prototype:** [Figma Prototype](https://www.figma.com/proto/fTavnSI8sRCw1EfXVYpU7G/Fax-Management?page-id=846%3A10142&node-id=846-11359&viewport=442%2C5606%2C0.29&t=w2AnKq9OQXODTdrD-1&scaling=contain&content-scaling=fixed&starting-point-node-id=846%3A11359&show-proto-sidebar=1)

**Office Fax\#’s:** [Practice Fax Numbers](https://docs.google.com/spreadsheets/d/1Pp-42OT22AIBktcVPqUmkf_0mGL5HMESMR5KKUjY-Aw/edit?usp=sharing)

## ---

## 

## **Success Metrics**

| Metric | Target |
| :---: | :---: |
| Reduction in average fax handling time | ≥ 30% |
| % of fax documents auto-classified as boarding sheets | ≥ 80% |
| SSM adoption rate for TXAUS OR Schedulers | ≥ 90% |

## ---

## **Technical Requirements**

### Data to Store in SSM

* ## Status’:

  * Waiting \- newly arrived faxes that have no meta data associated with them  
  * Reviewed \- faxes with meta data attached to them  
  * Closed \- When the fin\# matches a case in SSM  
  * Current \- menu option only:  Includes both Waiting and Reviewed faxes

* ## Fax document metadata (received date/time, received fax\#)

  * ## Entered patient full name

  * ## Entered procedure date

  * ## Entered FIN\#

  * ## Entered Date of Birth

  * Entered in Surgeon Name	

* ## All AI extracted Data from boarding forms

  * ## Appointment location

  * ## Patient name

  * ## Patient Type

  * ## Primary Surgeon

  * ## Funding Source (Insurance)

  * ## Diagnosis (ICD-10 codes)

  * ## Primary Procedure

  * ## Surgical Comments	

  * [TXAUS Example](https://docs.google.com/spreadsheets/d/1UkTO9iZ_5cWZmWmoUekcEnZ64ivN58ZbSSrhRnQyG6Q/edit?usp=sharing)

* ## Linked Cerner case number (if applicable)

* ## Document Activity

  * ## User Date/Time for each change

  * ## Changes for each field for boarding and support forms

  * ## Status changes \- do not overwrite these 

### Integrations

* ## RightFax → SSM: 

  * ## Secure ingestion of inbound fax documents 

  * ## Real-time or near-real-time delivery

* ## UI Path → SSM:

  * ## Identifying of document types

  * ## Extracting scheduling data to provide to SSM 

### Reporting Needs

* ## Fax volume by hospital / OR unit and date range 

* ## OR Scheduler throughput and handling time 

  * ## Fax Received date toTime to Fax Closed date/time

  * ## Per fax display days/hours/minutes/seconds

  * ## Date range 

  * ## Provide average time to close a fax per OR Scheduler

  * ## \# of faxes closed 

* ## Adoption and usage metrics 

### Permissions & Access

* ## OR Schedulers: view, classify, search, enter data, and link fax documents

* ## PAT role: for printing documents

* ## Hospital Viewer:  View, search

## ---

## **Feature Split**

1. Right Fax integration   
   1.  [DSSC-8492](https://ascensionjira.atlassian.net/browse/DSSC-8492) \- TXAUS Fax \- 1 Right Fax Integration   
      1. Sending faxes to a network folder  
      2. Reading from the network folder and intaking faxes to SSM  
      3. Sending incorrectly received faxes to another department  
2. Foundational UI Components:   
   1. [DSSC-8493](https://ascensionjira.atlassian.net/browse/DSSC-8493) \- TXAUS Fax \- 2 Foundational UI Components  
      1. Create separate work to build reusable components, including:  
      2. A standardized, themeable data table library (sortable, with actions) that can be used across various micro-apps.  
      3. Support for the combination search box (where the input type changes based on the selected search criteria, e.g., a date picker for "Procedure Date").  
3. Fax Management   
   1. [DSSC-8494](https://ascensionjira.atlassian.net/browse/DSSC-8494) \- TXAUS Fax \- 3 Fax Management   
      1. Fax list  
      2. Case list Task card,   
      3. filtering and searching  
      4. Fax processing  
         1. Boarding form  
         2. Support form  
         3. Pages: indexing document on category  
         4. Assigning faxes to cases based on fin\#  
         5. Incoming Cases checking for faxes with case fin\#  
         6. Move to Close   
4. PDF Document Viewer enhancements (available to all users)  
   1. [DSSC-8495](https://ascensionjira.atlassian.net/browse/DSSC-8495) \- TXAUS Fax \- 4 PDF Document Viewer enhancements  
      1. Rotate  
      2. Flip  
      3. Zoom in  
      4. Zoom out  
      5. Print  
      6. Download  
5. Split Document  
   1. [DSSC-8496](https://ascensionjira.atlassian.net/browse/DSSC-8496) \- TXAUS Fax \- 5 Split Document  
      1. Splitting a document into a second document  
      2. Maintaining integrity of original document  
      3. Data input for meta data  
      4. Closing out the split document function  
6. Document Activity   
   1. [DSSC-8497](https://ascensionjira.atlassian.net/browse/DSSC-8497) \- TXAUS Fax \- 6 Document Activity  
      1. Track User, Date/Time and type of activity  
      2. Display meta data changes  
7. Move to next document  
   1. [DSSC-8498](https://ascensionjira.atlassian.net/browse/DSSC-8498) \- TXAUS Fax \- 7 Move to next fax or document  
      1. Move to next fax within the pdf viewer for fax management  
      2. Move to next document within a single case  
8. UI Path  
   1. [DSSC-8499](https://ascensionjira.atlassian.net/browse/DSSC-8499) \- TXAUS Fax \- 8 Integration with UI Path  
      1. AI data display in fax mgmt

## ---

## Dependencies

* ## Ascension Technologies \- RightFax team 

* ## UI Path

## ---

## Appendix

* ## Rightfax integration request\# **REQ0204915**

* [Refinement questions 3/16](https://docs.google.com/document/d/1zd2tbbnAWBCnkb5VDh_TBoM54Ar7FXKT5ZRtlIbZpdM/edit?usp=sharing)  
* **December 2025**  
* **Total faxes \- 12,379**  
* **Total Pages \- 111,171**  
*   
* **FAX Numbers:**  
  * ASMCA- 512 370-5522