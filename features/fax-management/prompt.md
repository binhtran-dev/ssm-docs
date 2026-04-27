You are an expert product analyst and senior software architect. I will provide you with several inputs for a new feature called **Fax Management**:  
1. The PRD (Product Requirements Document): features/fax-management/Backend-Technical-Specification-TXAUS-Fax-Management.md
2. The backend technical specification: features/fax-management/Backend-Technical-Specification-TXAUS-Fax-Management.md 
3. The Figma design: features/fax-management/Figma-link.md
4. The existing architecture & infrastructure documentation located in the `/docs` folder  

Your task is to analyze **all four sources holistically** and produce a unified, structured output that captures the full product, technical, and architectural understanding of the feature.

Please provide the following:

---

### **1. Feature Overview**
- High‑level description of the Fax Management feature  
- End‑to‑end user flows (list and describe each flow)  
- Functional requirements (explicit + inferred from PRD, backend spec, Figma, and `/docs`)  
- Non‑functional requirements (performance, security, compliance, scalability, UX constraints, etc.)  
- Edge cases, constraints, and assumptions  

---

### **2. Technical Architecture & Specifications**
Using the backend spec and the existing architecture/infrastructure in `/docs`, provide:

- Required API endpoints (existing vs. new)  
- Request/response schemas  
- Events (domain events, pub/sub, webhooks, etc.)  
- Data models and storage considerations  
- Integration points with internal services or external fax providers  
- Technologies involved (frontend, backend, infrastructure, queues, databases, etc.)  
- Dependencies, architectural constraints, and alignment with existing system patterns  
- Sequence diagrams or step‑by‑step technical flows  

---

### **3. Monitoring & Observability**
Based on system standards in `/docs`:

- Logging requirements (what to log, log levels, correlation IDs, PII handling)  
- Metrics to track (business KPIs + system metrics)  
- Alerts (thresholds, failure scenarios, SLIs/SLOs)  
- Dashboards or monitoring tools recommended  
- Any required updates to existing monitoring frameworks  

---

### **4. Output Format**
Provide the final answer in a clean, structured format with clear headings and bullet points.  
Include diagrams (ASCII), tables, or flow breakdowns where helpful.

---

### **5. Additional Instructions**
- Resolve contradictions between PRD, backend spec, Figma, and `/docs` by calling them out explicitly.  
- Highlight missing information or unclear requirements.  
- Suggest improvements or optimizations if applicable.  
- Ensure the analysis is complete enough for engineering, QA, and design teams to begin implementation.