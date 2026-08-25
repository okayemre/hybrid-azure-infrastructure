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

### Hybrid identity sync method: PHS vs PTA
- ✅ **Decision:** Use Password Hash Synchronization (PHS) as the sign-in method for Microsoft Entra Connect.
- 🧠 **Context:** PHS requires no additional on-prem agent and keeps working even if SRV-DC01 goes offline (last synced hash remains valid in the cloud). Pass-through Authentication (PTA) was considered but rejected for this project's scale — a single test user doesn't exercise PTA's main advantage (real-time on-prem policy enforcement).
- ⚠️ **Trade-off:** Password hashes leave the on-prem environment (double-hashed, non-reversible). Not suitable for organizations with strict "credentials never leave on-prem" policies — PTA would be the answer there.

### UPN suffix mismatch resolution
- ✅ **Decision:** Added the tenant's default `*.onmicrosoft.com` domain as an alternative UPN suffix in on-prem AD, and updated the test user's UPN to use it instead of `@hybridlab.local`.
- 🧠 **Context:** `hybridlab.local` is not a publicly verifiable domain, so Microsoft Entra ID rejects cloud sign-in for UPNs using that suffix. Adding a custom domain to the tenant was avoided to keep the setup free and simple.
- ⚠️ **Trade-off:** The user's on-prem UPN no longer matches the AD domain name, which is a minor cosmetic inconsistency purely for demo purposes.

### Sync scope: OU-based filtering
- ✅ **Decision:** Configured Microsoft Entra Connect to sync only the `HybridLab-Staff` OU, not the full `hybridlab.local` domain.
- 🧠 **Context:** Default and built-in AD objects (Domain Controllers, Builtin, Computers, etc.) have no business value in the cloud and would clutter Entra ID with noise.
- ⚠️ **Trade-off:** Any future demo users must be created inside `HybridLab-Staff` (or its scope must be re-widened) to be synced.

### IE Enhanced Security Configuration disabled on SRV-DC01
- ✅ **Decision:** Temporarily disabled IE Enhanced Security Configuration for Administrators on SRV-DC01.
- 🧠 **Context:** The Entra Connect installation wizard uses an embedded browser control to sign in to Microsoft Entra ID; IE ESC blocked `login.microsoftonline.com` by default, preventing sign-in.
- ⚠️ **Trade-off:** Slightly reduces browser hardening on the server. Acceptable for a lab VM with no general web browsing use case.

### Admin account for Entra Connect: dedicated cloud account vs MSA-linked Global Admin
- ✅ **Decision:** Used a dedicated cloud-only Global Administrator account instead of the personal Microsoft account (MSA) originally used to create the tenant.
- 🧠 **Context:** MSA-linked tenant owner accounts authenticate as external/guest-style identities from certain legacy tools' perspective, which Entra Connect's sign-in flow rejects (`AADSTS50020`).
- ⚠️ **Trade-off:** None — this is best practice regardless; MSA-linked accounts shouldn't be used for ongoing admin operations anyway.

---

## 🏗️ Architecture Strategy

### Terraform vs. Portal split
- ✅ **Decision:** Terraform manages the Landing Zone, AKS, Key Vault, ACR, and Log Analytics. The VPN Gateway and Point-to-Site connection are set up manually in the Portal.
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

### VPN topology: Site-to-Site → Point-to-Site pivot
- ✅ **Decision:** Use Point-to-Site (P2S) VPN instead of Site-to-Site (S2S).
- 🧠 **Context:** The home ISP uses DS-Lite — no public IPv4 is available on the router's WAN interface, which S2S IPsec tunnels require. P2S initiates the connection outbound from SRV-DC01, so no public IPv4 or inbound port forwarding is needed.
- ⚠️ **Trade-off:** P2S is a single-client tunnel from SRV-DC01, not a true network-to-network tunnel — only that server reaches Azure, not the full on-prem subnet automatically.

### GatewaySubnet prerequisite (Landing Zone pulled forward)
- ✅ **Decision:** Provisioned a minimal VNet with a `GatewaySubnet` via Terraform ahead of the full Milestone E Landing Zone scope.
- 🧠 **Context:** Azure VPN Gateway hard-requires an existing VNet with a subnet named exactly `GatewaySubnet` — Milestone C depended on part of Milestone E.
- ⚠️ **Trade-off:** Landing Zone work is split across two milestones, same pattern as the earlier ACR-before-AKS case.

### P2S authentication method
- ✅ **Decision:** Self-signed root/child certificate pair (Azure certificate auth), generated via PowerShell on SRV-DC01.
- 🧠 **Context:** Basic Gateway SKU only supports certificate-based auth over SSTP — RADIUS/Azure AD auth require higher SKUs.
- ⚠️ **Trade-off:** Manual certificate lifecycle (no auto-renewal, no revocation infrastructure) — acceptable for a single-client lab connection.

### VPN Gateway SKU & teardown strategy
- ✅ **Decision:** Basic SKU chosen for cost (~$0.04/hr vs. ~$0.19/hr for VpnGw1). Gateway and its Public IP deleted after a successful P2S connectivity test.
- 🧠 **Context:** VPN Gateway bills hourly regardless of usage; no later milestone (D–K) functionally requires an active tunnel. Certificates, VNet, and GatewaySubnet remain in place for a quick re-provision if a live demo is needed later.
- ⚠️ **Trade-off:** Re-provisioning takes ~30–45 minutes each time it's needed again — documented via screenshots instead of a persistently running resource.