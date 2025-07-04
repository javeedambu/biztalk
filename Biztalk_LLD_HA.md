## High Availability, Disaster Recovery & Backup Strategy

### 1. Site Failure Handling

#### Active-Active Regional Deployment

BizTalk is deployed in two geographically isolated data centers — **GB (Great Britain)** and **US (United States)** — in a **fully independent, active-active configuration**. Each environment includes:

- A single BizTalk Server VM
- A SQL Server backend deployed on a **Windows Server Failover Cluster (WSFC)**
- No integration or dependency between GB and US BizTalk instances

Each business system interacts only with its **local BizTalk instance**, and there is **no cross-region message routing or BizTalk failover** built into the platform.

#### Business System Redundancy

Several business applications are architected for **cross-region redundancy**, configured in either **Active-Active** or **Active-Passive** modes:

- In normal operation, applications use the local BizTalk instance (e.g., GB apps use GB BizTalk).
- If a **complete site outage** occurs (e.g., GB data center failure), **Active-Passive systems** are manually failed over by operations teams.
- The **passive instance** in the alternate region (e.g., US) becomes active and consumes services from the **local BizTalk instance** in that region.

BizTalk does **not** perform any automatic failover or participate in this cross-region handoff.

#### BizTalk Recovery Risks Post-Outage

When the failed site is restored, **BizTalk services may resume automatically**, which introduces a risk of **unintended message processing**, especially if:

- Business systems are still running in failover mode in the alternate region
- BizTalk applications, ports, and host instances start processing data independently

**Precautions:**

- **Coordinate recovery** with application teams to avoid conflicts
- **Manually control the startup** of BizTalk host instances (disable auto-start if necessary)
- Validate the **state of business systems** before enabling message flows
- Use **runbooks** to govern reactivation and avoid duplicate or conflicting transactions

---

### 2. Backup and Recovery Strategy

Rubrik is the enterprise backup solution used for both BizTalk and SQL Server components. It supports reliable and recoverable backup with differing mechanisms for each tier.

#### BizTalk Server VM Backup

- **Method**: Image-based backup via VMware integration with Rubrik
- **Recovery**:
  - Full VM recovery is **fast and streamlined**
  - Supports instant restore with minimal downtime
  - No BizTalk reinstallation typically required

#### SQL Server (Database Tier) Backup

- **Method**:
  - **Agent-based backup** using Rubrik
  - Includes full file system + system state
  - **Databases and transaction logs** backed up every **30 minutes**

- **Recovery Process**:
  1. Provision a new base VM with the required SQL Server configuration
  2. Restore system state and local drives from Rubrik
  3. Restore SQL databases from latest **full + log backups**
  4. Apply transaction logs for **point-in-time recovery**

- **Recovery Considerations**:
  - Longer RTO due to provisioning and log replay
  - Ensure correct versioning, paths, and service accounts are used
  - Validate BizTalk’s ability to connect to restored databases

#### Post-Restore Validation

Following any restore (BizTalk or SQL):

- Verify BizTalk Management DB availability
- Check that host instances are correctly configured
- Ensure receive/send ports, orchestrations, and tracking are operational
- Confirm DNS/IP configuration and service binding integrity

#### Recommendations

- Perform **regular DR drills** to validate full-stack recovery
- Document **runbooks** for BizTalk and SQL Server restore operations
- Include BizTalk-specific steps in your DR plan to prevent premature processing post-recovery

---

---

# 🧾 BizTalk Recovery Runbook

## 📁 Scenarios Covered

1. [BizTalk VM Recovery (via VMware / Rubrik)](#1-biztalk-vm-recovery-via-vmware--rubrik)
2. [SQL Server VM / Database Recovery](#2-sql-server-vm--database-recovery)
3. [Complete Site Outage and Recovery](#3-complete-site-outage-and-recovery)
4. [Final Health & Coordination Checklist](#final-checklist-all-scenarios)

---

## 🔧 1. BizTalk VM Recovery (via VMware / Rubrik)

### Trigger:

* BizTalk VM is unreachable or corrupted

### Steps:

1. **Verify Failure**

   * Check VM status in vCenter
   * Ensure host and storage are healthy
   * Attempt RDP or console login

2. **Initiate Restore via Rubrik**

   * Open Rubrik UI
   * Locate BizTalk VM backup
   * Choose **Instant Recovery** or **Full Restore**
   * Restore to original or new location

3. **Post-Restore Validation**

   * Ensure Windows boots and joins domain
   * Start required services:

     * `Enterprise SSO`
     * BizTalk Host Instances
   * Confirm BizTalk Admin Console loads without errors

4. **Message Queue Handling**

   * Check suspended instances and pending messages
   * Resume or terminate messages as appropriate

5. **Coordinate Before Resuming Processing**

   * Ensure upstream/downstream systems are back in original state (not in failover mode)

---

## 🗄️ 2. SQL Server VM / Database Recovery

### Trigger:

* SQL VM crash, corruption, or total loss

### Steps:

1. **Provision New SQL Base VM**

   * Install supported SQL Server version
   * Patch to match original version
   * Join domain
   * Reconfigure WSFC settings (if needed)

2. **Restore Drives (If Required)**

   * Use Rubrik agent-based backup
   * Restore OS/system state and data volumes

3. **Restore Databases**

   * Restore from Rubrik:

     * `BizTalkMsgBoxDb`
     * `BizTalkMgmtDb`
     * `BizTalkDTADb`
     * `SSODB`
   * Use:

     * Latest **Full Backup**
     * * 30-minute **Transaction Logs** for point-in-time recovery

4. **Post-Restore Tasks**

   * Check SQL logins, agent jobs, and linked servers
   * Verify BizTalk SQL user permissions
   * Confirm BizTalk server can connect and function

5. **Health Check**

   * Open BizTalk Admin Console
   * Run **BizTalk Health Monitor** (optional)
   * Verify no MsgBox flooding or SQL errors

---

## 🌐 3. Complete Site Outage and Recovery

### Trigger:

* Full datacenter outage (e.g., power, network, infra)

### Steps:

1. **During Outage**

   * Active-Passive business systems fail over to the other region
   * BizTalk in failed site is unavailable and **must not auto-start upon return**

2. **Post-Outage: Controlled Startup**

   * After infrastructure restored, **disable BizTalk Host Instances** on boot
   * Manually control startup of:

     * `Enterprise SSO`
     * Host Instances
     * Send/Receive Ports

3. **App Team Coordination**

   * Ensure business applications have failed back
   * Confirm no dual-processing will occur

4. **Start BizTalk Services**

   * Gradually enable host instances
   * Enable ports and orchestrations in a staged manner

5. **Monitor**

   * Watch suspended queues
   * Check tracking and integration status

---

## ✅ Final Checklist (All Scenarios)

| Task                                       | Status |
| ------------------------------------------ | ------ |
| VM restored and boots correctly            | ✅      |
| SQL Server accessible and healthy          | ✅      |
| BizTalk Host Instances started as needed   | ✅      |
| Enterprise SSO service running             | ✅      |
| Receive/Send Ports enabled                 | ✅      |
| Message queues clear or being processed    | ✅      |
| Suspended/zombie instances handled         | ✅      |
| App teams coordinated for cutover/failback | ✅      |
| Integration tested post-recovery           | ✅      |

---

