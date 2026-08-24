# 📘 Project Decisions

A short, honest log of every architecture and technical decision in this project —
the **why**, not just the **what**.

**Legend:** 🏗️ Architecture · 🔐 Security/Identity · 📊 Monitoring · 💰 Cost · 🧱 IaC/Tooling

---

## 🧱 Repository & Documentation

### Repository name & README language
- ✅ **Decision:** Repo named `hybrid-azure-infrastructure`. README is bilingual (EN/DE) in a single file, with anchor links for language switching.
- 🧠 **Context:** Kept separate from an older, unrelated repository. Bilingual README serves both English- and German-speaking readers.
- ⚠️ **Trade-off:** One extra section to maintain per update, but no separate files to keep in sync.

---

## 🧱 Infrastructure as Code

### Resource naming strategy
- ✅ **Decision:** `random_string` suffix for globally unique names. Storage Account: 10 chars. Key Vault: 6 chars. ACR: ~10 chars. No hyphens.
- 🧠 **Context:** Several Azure resources need globally unique names. A shared module keeps this consistent everywhere.
- ⚠️ **Trade-off:** Slightly less readable resource names, in exchange for zero naming collisions.

### Subscription authentication
- ✅ **Decision:** Use the `ARM_SUBSCRIPTION_ID` environment variable. No subscription IDs hardcoded anywhere.
- 🧠 **Context:** This repository is public — secrets and account-identifying values must never be committed.
- ⚠️ **Trade-off:** Every environment must set the variable manually before running Terraform.

---

## 🔐 Security & Identity

### Key Vault authorization model
- ✅ **Decision:** `rbac_authorization_enabled = true`.
- 🧠 **Context:** Modern RBAC-based authorization instead of legacy access policies — current Azure best practice.
- ⚠️ **Trade-off:** None significant — RBAC is the recommended path going forward.

### Test user & OU structure
- ✅ **Decision:** Created OU `HybridLab-Staff` with one test user representing a standard employee account.
- 🧠 **Context:** Demonstrates hybrid identity — this account will sync to Azure AD via Entra Connect in Milestone D.
- ⚠️ **Trade-off:** None — exists purely for demonstration.

---

## 🏗️ Architecture Strategy

### Terraform vs. Portal split
- ✅ **Decision:** Terraform manages the Landing Zone, AKS, Key Vault, ACR, and Log Analytics. The VPN Gateway and Site-to-Site connection are set up manually in the Portal.
- 🧠 **Context:** Wizard-heavy, one-time-setup resources go through the Portal. Repeatable, code-managed resources go through Terraform.
- ⚠️ **Trade-off:** VPN setup isn't reproducible via `terraform apply` — documented manually with screenshots instead.

### Project naming
- ✅ **Decision:** App name `hybridlab`, environment `dev`.
- 🧠 **Context:** Renamed from an earlier personal-name-based choice to something project-wide.

### VM network mode
- ✅ **Decision:** On-prem VM network adapter set to Bridged (not NAT).
- 🧠 **Context:** NAT causes double-NAT behind the home router, breaking VPN port forwarding needed for Milestone C.
- ⚠️ **Trade-off:** VM shares the home network's broadcast domain — requires care with services like DHCP.

### Static IP for domain controller
- ✅ **Decision:** SRV-DC01 assigned static IP `192.168.0.15`, excluded from the router's DHCP pool.
- 🧠 **Context:** AD DS, DNS, and DHCP configuration all depend on a stable DC address. The chosen IP falls within the router's DHCP range (`.2`–`.253`), so an explicit exclusion/reservation was added on the router to prevent conflicts.
- ⚠️ **Trade-off:** One extra manual step on the router, outside this project's own documentation surface.

### Forest & domain name
- ✅ **Decision:** New forest, root domain `hybridlab.local`. NetBIOS name `HYBRIDLAB`.
- 🧠 **Context:** First domain controller in the environment; name reflects the project, not an individual.
- ⚠️ **Trade-off:** `.local` isn't publicly routable — Entra Connect will need an alternate UPN suffix later (Milestone D).

### DHCP scope
- ✅ **Decision:** Scope `192.168.0.100`–`192.168.0.150` created and authorized, left inactive.
- 🧠 **Context:** The home router's DHCP pool covers nearly the whole subnet, leaving no safe range to avoid conflicts.
- ⚠️ **Trade-off:** Role and scope are documented but not actively leasing addresses.

