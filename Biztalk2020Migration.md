
---

## **Introduction**

### **Overview**

This document outlines the Low-Level Design (LLD) for the upgrade of Microsoft BizTalk Server 2016 environments with backend SQL Server 2016 (Standard Edition, running on Windows Server Failover Clustering with FCI) to Microsoft BizTalk Server 2020 with SQL Server 2022 Standard Edition.

Each deployment consists of three servers:

* One BizTalk Server (single node)
* Two SQL Server nodes in a clustered (FCI) configuration

This upgrade spans four environments:

* **GB Production** (`p.local`)
* **GB Test** (`t.local`)
* **US Production** (`p.local`)
* **US Test** (`t.local`)

The environments are isolated, with no data replication or synchronization between GB and US. However, business applications consuming BizTalk can failover between regions in either Active/Active or Active/Passive modes. In Active/Passive mode, manual intervention is required to reconfigure BizTalk send/receive ports during failover.

This upgrade is essential due to the end-of-life (EOL) status of Windows Server 2016, SQL Server 2016, and BizTalk Server 2016. All upgraded environments will maintain *like-for-like* functionality, configurations, and roles, while modernizing the software and platform stack.

### **Low Level Design Scope**

This document defines the architecture and deployment specifics of the upgraded environments, including:

* Design of the new BizTalk Server 2020 and SQL Server 2022 FCI infrastructure
* Logical and physical architecture details
* Adapter usage and BizTalk runtime configuration
* Compatibility with VMware virtual infrastructure and PowerMax SAN-backed storage
* Constraints, interfaces, and operational dependencies
* BizTalk-specific component decisions (e.g., Enterprise SSO, runtime only, Business Rules Engine)
* No changes in integration flows or business logic (application-level migrations are outside scope)

**Key Characteristics of Migration:**

* **Migration Approach:** Parallel build (greenfield)
* **Target = Source Parity:** Same edition and roles — BizTalk 2020 Enterprise, SQL 2022 Standard
* **Infrastructure:**

  * VMware-hosted VMs
  * PowerMax SAN storage
  * SQL Server using RDM for database and quorum storage
* **Post-install Configuration:**

  * Configured: Enterprise SSO, Group, BizTalk Runtime, Business Rules Engine
  * Not Configured: BAM Tools, REST APIs, TMS
* **Adapters in Use:**

  * Native: FILE, SFTP, SMTP, FTPS, SCHEDULE
  * Third-Party: nSoftware 2024 Adapters for FTPS and S3

---

## **Low Level Design**

### **Component 1: BizTalk Server 2020 Environment**

#### **Logical Design**

The upgraded environment retains the existing topology and integration behavior while replacing underlying OS, BizTalk, and SQL versions.

Each of the four environments will follow this logical structure:

##### **BizTalk Server Layer:**

* One BizTalk Server 2020 (Enterprise Edition) per environment
* Hosted on Windows Server 2022
* Part of the respective domain: `p.local` or `t.local`
* Configured with:

  * Enterprise SSO
  * Group
  * BizTalk Runtime
  * Business Rules Engine
* Not configured:

  * BAM Tools
  * REST APIs
  * BizTalk TMS

##### **Adapters and Interfaces:**

* Native Adapters: FILE, SFTP, SMTP, FTPS, SCHEDULE
* nSoftware Adapters 2024:

  * FTPS and S3 used for specific integrations
  * Installed and licensed per new BizTalk installation
* Custom ports, orchestrations, and bindings will be migrated in batches

##### **SQL Server Layer:**

* SQL Server 2022 Standard (Failover Cluster Instance)
* Hosted on two VMs (per environment) configured with WSFC
* Shared disk (RDMs) on PowerMax SAN for:

  * System databases
  * BizTalk MessageBox, DTA, SSO, and other custom BizTalk databases
  * SQL Server logs
* Supports High Availability with automatic failover at the database level
* BizTalk’s connection to SQL remains static (virtual network name of FCI)

##### **Virtual Infrastructure:**

* All VMs hosted on VMware
* VMDKs used for OS volumes
* RDMs (VMFS passthrough) for SQL data/log volumes and quorum disk
* VMware HA and DRS policies aligned with WSFC node placement

##### **Cluster Layer:**

* WSFC cluster configured for SQL Server HA
* Separate clusters per environment
* Cluster resources:

  * SQL Server FCI role
  * Quorum disk (witness)
  * Listener IPs and DNS entries

##### **Active Directory Integration:**

* BizTalk and SQL Servers joined to:

  * `p.local` (for GB/US Prod)
  * `t.local` (for GB/US Test)
* Separate service accounts provisioned per environment
* Kerberos authentication supported and retained from current setup

##### **Migration Behavior:**

* Migration is non-intrusive (parallel setup)
* Legacy BizTalk servers will remain operational during the phased migration
* BizTalk applications, bindings, host instances, and ports will be migrated in batches
* Post-validation of each batch, applications on legacy environment will be disabled
* Final decommissioning of legacy BizTalk and SQL servers post full cutover

---

### **Logical Topology Diagram (Textual)**

```
+------------------------+      +------------------------+
|   BizTalk Server 2020  | ---> | SQL Server 2022 FCI    |
|   (WS 2022, Domain VM) |      | (2-node WSFC Cluster)  |
|                        |      | - SQL Node 1           |
| - Adapters: FILE, FTP  |      | - SQL Node 2           |
| - nSoftware: S3, FTPS  |      | - Shared Storage (RDM) |
+------------------------+      +------------------------+

          |                            |
          |----> PowerMax SAN <--------|
          |                            |
      (OS VMDKs and SQL RDMs)
```

> This layout is repeated for each of the four environments (GB/US – Test/Prod)

---

