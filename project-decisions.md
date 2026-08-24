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

---

## 🏗️ Architecture Strategy

### Terraform vs. Portal split
- ✅ **Decision:** Terraform manages the Landing Zone, AKS, Key Vault, ACR, and Log Analytics. The VPN Gateway and Site-to-Site connection are set up manually in the Portal.
- 🧠 **Context:** Wizard-heavy, one-time-setup resources go through the Portal. Repeatable, code-managed resources go through Terraform.
- ⚠️ **Trade-off:** VPN setup isn't reproducible via `terraform apply` — documented manually with screenshots instead.

### Project naming
- ✅ **Decision:** App name `mrsblog`, environment `dev`.
- 🧠 **Context:** Used consistently across resource names and Terraform variables.

---

<!--
📌 Add new decisions below, under the relevant category header.
Use the same format: ✅ Decision · 🧠 Context · ⚠️ Trade-off
-->
