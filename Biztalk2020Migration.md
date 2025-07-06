---

## **Low Level Design**

### **Component 1: BizTalk Server 2020 Environment**

---

#### **Physical Design**

##### **Server Details**

The following table outlines the physical (virtual) server allocations, roles, and specifications per environment.

| Component      | Role                            | Count | OS Version          | CPU / RAM            | Disk Layout (Example)                                                               | Domain                  |
| -------------- | ------------------------------- | ----- | ------------------- | -------------------- | ----------------------------------------------------------------------------------- | ----------------------- |
| BizTalk Server | Application Server              | 1     | Windows Server 2022 | 4 vCPU / 16–32 GB    | C:\ OS (VMDK) <br> D:\ BizTalk Data                                                 | p.local / t.local |
| SQL Node 1     | SQL Server (Active/Passive FCI) | 1     | Windows Server 2022 | 8–16 vCPU / 32–64 GB | C:\ OS (VMDK) <br> E:\ SQL Data (RDM) <br> F:\ SQL Logs (RDM) <br> Q:\ Quorum (RDM) | p.local / t.local |
| SQL Node 2     | SQL Server (Active/Passive FCI) | 1     | Windows Server 2022 | 8–16 vCPU / 32–64 GB | Same as Node 1                                                                      | p.local / t.local |

> Each region (GB/US) and environment (Prod/Test) has its own independent deployment.

**VM Platform:**

* VMware vSphere 7.x or higher
* VMDKs hosted on PowerMax SAN (for OS)
* SQL data, logs, and quorum are hosted on RDMs provisioned from the same SAN
* SQL uses shared storage in WSFC configuration (non-CSV model)

---

##### **Configuration Settings**

###### **BizTalk Server**

| Setting Area          | Value / Notes                                                                     |
| --------------------- | --------------------------------------------------------------------------------- |
| BizTalk Edition       | Enterprise Edition 2020                                                           |
| Host Configuration    | Dedicated host and host instances per adapter type (FILE, SFTP, SMTP, etc.)       |
| Service Accounts      | Separate domain service accounts for SSO, Hosts, Rules Engine                     |
| Custom Adapters       | nSoftware 2024 Adapters (FTPS, S3) installed post BizTalk configuration           |
| Feature Configuration | Only: Enterprise SSO, Group, Runtime, BRE <br> Skipped: BAM Tools, REST APIs, TMS |
| BizTalk Backup Jobs   | Enabled post-configuration (via SQL Agent Jobs, part of BizTalk install)          |
| Windows Features      | Required IIS, .NET Framework 4.8+, HTTP Activation, Message Queuing, etc.         |
| Logging               | Event Viewer, BizTalk Admin Console, and third-party Syslog if configured         |

###### **SQL Server 2022 (Standard) FCI**

| Setting Area          | Value / Notes                                                       |
| --------------------- | ------------------------------------------------------------------- |
| SQL Edition           | SQL Server 2022 Standard (Failover Clustered Instance)              |
| Cluster Nodes         | 2                                                                   |
| SQL Service Accounts  | Separate AD service account                                         |
| Storage Configuration | RDMs for Data, Logs, TempDB, Quorum                                 |
| Quorum Disk           | Dedicated 1GB RDM (or witness share if no quorum disk)              |
| SQL FCI Listener Name | Fixed, static listener name per environment (e.g., `BTSQLPRODGB01`) |
| SQL Agent Jobs        | BizTalk Maintenance Jobs enabled                                    |
| Antivirus Exclusions  | Configured per Microsoft SQL best practices                         |
| Patching              | Coordinated across nodes using rolling updates in WSFC              |

###### **VMware & Storage**

| Area               | Value / Notes                                                           |
| ------------------ | ----------------------------------------------------------------------- |
| Hypervisor         | VMware vSphere (7.0 or later)                                           |
| Guest OS           | Windows Server 2022 Standard/Datacenter                                 |
| Storage Backend    | PowerMax SAN                                                            |
| OS Disks           | VMDK                                                                    |
| SQL Data/Logs      | RDM presented from SAN to each SQL node                                 |
| Cluster Disks      | RDM (same LUN shared to both SQL nodes)                                 |
| Backup Integration | Snapshots disabled for SQL disks; backup via SQL-aware backup solutions |

---

##### **Policy Settings**

###### **BizTalk Host & Host Instances**

| Policy Area             | Design Approach                                                      |
| ----------------------- | -------------------------------------------------------------------- |
| Host Separation         | Separate hosts for Receive, Send, Orchestration, Tracking            |
| Host Instance Isolation | Host instances run under least-privileged service accounts           |
| Adapter Placement       | FILE/SFTP/FTPS on separate receive hosts where needed                |
| Tracking Settings       | Enabled for all production BizTalk hosts; Test tracking kept minimal |

###### **Cluster Policy**

| Policy Area         | Design Approach                                                         |
| ------------------- | ----------------------------------------------------------------------- |
| Node Affinity       | Preferred owner set on SQL nodes; Automatic failback not enabled        |
| Quorum              | Node and Disk Majority (or Node and File Share Majority, as applicable) |
| Heartbeat & Timeout | WSFC defaults unless tuned per latency needs                            |

###### **Maintenance Policies**

| Area                   | Policy / Notes                                                              |
| ---------------------- | --------------------------------------------------------------------------- |
| OS Patching            | Coordinated patch windows for BizTalk and SQL Nodes (staggered)             |
| SQL Patching           | Via WSFC rolling updates                                                    |
| Backup Strategy        | Daily full backups, 15-minute log backups (if configured)                   |
| Antivirus Exclusion    | Applies to BizTalk MsgBox, tracking db, temp paths, SQL data/log folders    |
| Monitoring Integration | BizTalk Perf Counters, Event Logs, SQL Logs fed to existing SIEM (optional) |

---
