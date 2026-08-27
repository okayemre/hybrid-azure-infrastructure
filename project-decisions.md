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

### Resource tagging

- ✅ **Decision:** A `common_tags` local (`project`, `environment`, `managed_by`) is applied to all taggable network resources (resource groups, VNet, NSGs).
- 🧠 **Context:** Supports cost tracking and future policy enforcement, matching the project's governance goals.
- ⚠️ **Trade-off:** Azure subnets and NSG associations don't support tags at the resource type level — tagging coverage is necessarily partial.

### Separate Terraform state per layer

- ✅ **Decision:** Split infrastructure into three independent Terraform roots — `terraform/terraform-network`, `terraform/terraform-workload`, and `terraform/terraform-platform` — each with its own remote state file, connected via `terraform_remote_state` data sources.
- 🧠 **Context:** Isolates blast radius (a mistake in one layer's `apply` can't affect another's state) and mirrors how real organizations typically separate landing zone, workload, and platform-service ownership. All three roots were grouped under a single `terraform/` parent folder for repository clarity.
- ⚠️ **Trade-off:** No single `apply` provisions everything — each root is applied independently, and lower layers must expose every value higher layers need via explicit outputs.

### AKS `node_provisioning_profile` requirement

- ✅ **Decision:** Added an explicit `node_provisioning_profile { mode = "Manual", default_node_pools = "None" }` block to the AKS resource.
- 🧠 **Context:** Node Autoprovisioning (NAP) became GA in the `azurerm` provider, making this block required — its absence caused a hard `terraform apply` failure. `Manual`/`None` keeps NAP disabled, since the project uses a fixed, manually-defined node pool.
- ⚠️ **Trade-off:** None significant — this is now a mandatory block regardless of whether NAP is used.

### Helm provider v3 migration

- ✅ **Decision:** Pinned the `helm` provider to `~> 3.2` and used the current object-attribute syntax (`kubernetes = { ... }`) instead of the legacy nested block syntax.
- 🧠 **Context:** Helm provider v3.0.0 (June 2025) replatformed on the Terraform Plugin Framework, changing `kubernetes { }` from a block to an object attribute — the older syntax now fails validation.
- ⚠️ **Trade-off:** None — this is simply the current correct syntax.

### Node pool VM size selection

- ✅ **Decision:** Used `Standard_D2s_v3` for the AKS system node pool.
- 🧠 **Context:** The subscription's regional SKU allowlist rejected the initially planned `Standard_B2s`; a same-spec `Standard_B2s_v2` was then rejected by AKS itself, since burstable (B-series) VMs aren't permitted for system node pools regardless of core/RAM count. `Standard_D2s_v3` is a non-burstable SKU that satisfies both constraints.
- ⚠️ **Trade-off:** Slightly higher cost than a burstable SKU would have been, negligible for a short-lived dev/lab cluster.

### ACR image verification method

- ✅ **Decision:** Verified `AcrPull` access by importing a public image directly into ACR (`az acr import`) rather than building and pushing locally.
- 🧠 **Context:** No local Docker installation is required on the dev machine — `az acr import` copies an image server-side between registries.
- ⚠️ **Trade-off:** Only proves pull access, not a full CI build/push pipeline — acceptable for this milestone's scope; a real build pipeline is a listed extension idea.

### Terraform state storage protection

- ✅ **Decision:** Enabled blob versioning and soft-delete (7-day retention) on the `sthybridlabtfstate01` storage account via Azure CLI.
- 🧠 **Context:** This account holds the only files whose loss would actually break the project — the three `.tfstate` files. The account itself was created outside Terraform, so this hardening was applied directly rather than through a new Terraform root just to manage its own state storage.
- ⚠️ **Trade-off:** A manual, undocumented-in-code step — anyone rebuilding this project from scratch must remember to apply it separately.

### Blob recovery with versioning + soft-delete both enabled

- ✅ **Decision:** Validated state storage recovery using a disposable test blob, not a real `.tfstate` file — deleted it, then restored it via "Make current version" (version promotion), not `az storage blob undelete`.
- 🧠 **Context:** With both versioning and soft-delete active, deleting a blob doesn't create a blob-level "soft-deleted" object — it just makes the previous version non-current. `az storage blob undelete` targets the former case and returns `{"undeleted": null}` on the latter; confirmed via `az storage blob list --include dv`, which showed a version record but no current-version pointer. The actual recovery path is promoting the prior version back to current.
- ⚠️ **Trade-off:** None — this is a factual correction to the recovery procedure documented in Milestone I, not a design trade-off.

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

### NSG strategy — one NSG per functional subnet

- ✅ **Decision:** Each functional subnet (ingress, platform, workload) gets its own NSG (`nsg-ingress-dev`, `nsg-platform-dev`, `nsg-workload-dev`), associated via `azurerm_subnet_network_security_group_association`. `GatewaySubnet` intentionally has no NSG attached.
- 🧠 **Context:** Different traffic patterns per layer require different rule sets; a shared NSG would be either too permissive or wrongly restrictive.
- ⚠️ **Trade-off:** Rule sets are still minimal/empty at this stage — actual traffic rules will be added per-service in later milestones.

### Workload subnet NSG — missing inbound rule

- ✅ **Decision:** Added explicit NSG rules allowing inbound traffic from `Internet` on ports 80 and 443 to the workload subnet's NSG.
- 🧠 **Context:** The workload NSG was intentionally left empty in Milestone E; Azure's default rules allow only VNet-internal traffic and load balancer health probes, silently dropping all external requests. This blocked the Ingress Controller's public IP until diagnosed.
- ⚠️ **Trade-off:** None — this is the minimum necessary opening; no broader ports or sources were added.

### ACR authentication: Managed Identity vs. admin credentials

- ✅ **Decision:** Granted the AKS kubelet identity the `AcrPull` role on the Container Registry (`admin_enabled = false`).
- 🧠 **Context:** No credentials to store, rotate, or leak — Azure handles the token exchange transparently at the node level.
- ⚠️ **Trade-off:** None significant — this is the current recommended pattern for AKS-to-ACR access.

### Key Vault network access: Public

- ✅ **Decision:** `public_network_access_enabled = true` on the Key Vault and ACR.
- 🧠 **Context:** Simpler for a 4-week lab project; RBAC already restricts who/what can read secrets regardless of network path.
- ⚠️ **Trade-off:** Network-layer defense-in-depth (Private Endpoint) is skipped — a reasonable follow-up if the project is extended (Milestone K).

### Key Vault CSI driver identity: kubelet identity vs. Workload Identity federation

- ✅ **Decision:** `SecretProviderClass` uses `useVMManagedIdentity: true` with the AKS kubelet identity, not Workload Identity federation.
- 🧠 **Context:** The CSI driver add-on's own auto-created identity defaulted to a federated/OIDC token flow, which failed with `AADSTS70025` (no federated credential configured). VM Managed Identity uses the node's existing IMDS-based identity instead, requiring no extra federation setup.
- ⚠️ **Trade-off:** Every pod on every node can request a token for the kubelet identity — less isolated than per-workload Workload Identity federation. Acceptable for a single-tenant lab cluster; production would warrant Workload Identity instead.

### Key Vault purge protection: considered, not enabled

- ✅ **Decision:** Left `purge_protection_enabled` unset (default `false`) on the Key Vault.
- 🧠 **Context:** Purge protection is irreversible once enabled — even a fully deleted Key Vault stays in a soft-deleted, unpurgeable state for the retention period (default 90 days). For a dev/lab project expected to be torn down at the end of the course, this outweighs the extra protection. Soft-delete alone (already the RBAC Key Vault default) covers accidental secret deletion.
- ⚠️ **Trade-off:** No protection against someone with sufficient permissions purging the vault outright — an accepted risk for this project's lifecycle.

### GitHub Actions authentication: OIDC over stored secrets

- ✅ **Decision:** Created an Azure AD App Registration with a federated identity credential trusting GitHub's OIDC issuer, instead of a service principal with a stored client secret.
- 🧠 **Context:** Continues the project's no-stored-credentials pattern (MSI-based `oms_agent` auth, RBAC-only Key Vault) — GitHub Actions exchanges a short-lived, repo-and-branch-scoped token at runtime, with nothing to rotate or leak in repository secrets.
- ⚠️ **Trade-off:** More setup steps than a client secret (App Registration, service principal, federated credential, two role assignments) for a security property that doesn't visibly change day-to-day usage.

### GitHub's OIDC subject format changed for new repositories

- ✅ **Decision:** Added a second federated identity credential matching GitHub's newer immutable-ID subject format, alongside the original classic-format one.
- 🧠 **Context:** Since July 2026, GitHub issues OIDC tokens for newly created repositories with organization and repository numeric IDs embedded in the subject (`repo:owner@<org_id>/repo@<repo_id>:ref:refs/heads/main`), not just the classic `repo:owner/repo:ref:...` format. The first pipeline run failed with `AADSTS700213` because the federated credential only matched the classic format; the actual subject was read directly from the error message.
- ⚠️ **Trade-off:** Two federated credentials to maintain instead of one, in case the format changes again or a workflow ever presents the older style.

### CI/CD access to AKS: Azure RBAC Cluster Admin Role, not Kubernetes RBAC

- ✅ **Decision:** Granted the GitHub Actions service principal the "Azure Kubernetes Service Cluster Admin Role" (an Azure RBAC role) rather than binding it to a Kubernetes Role/RoleBinding.
- 🧠 **Context:** The cluster has no Azure AD/Kubernetes RBAC integration configured (kept simple since Milestone F). This role lets `az aks get-credentials --admin` return a client-certificate-based kubeconfig that bypasses Kubernetes-level RBAC entirely, avoiding the need to set up an authorization layer just for one pipeline.
- ⚠️ **Trade-off:** The pipeline identity has full cluster-admin access rather than a scoped permission set limited to the `sample-app` namespace — acceptable for a single-app lab cluster, not a pattern to carry into a multi-tenant cluster.

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
- ⚠️ **Trade-off:** Landing Zone work is split across two milestones; documented here to explain the reordering.

### P2S authentication method

- ✅ **Decision:** Self-signed root/child certificate pair (Azure certificate auth), generated via PowerShell on SRV-DC01.
- 🧠 **Context:** Basic Gateway SKU only supports certificate-based auth over SSTP — RADIUS/Azure AD auth require higher SKUs.
- ⚠️ **Trade-off:** Manual certificate lifecycle (no auto-renewal, no revocation infrastructure) — acceptable for a single-client lab connection.

### VPN Gateway SKU & teardown strategy

- ✅ **Decision:** Basic SKU chosen for cost (~$0.04/hr vs. ~$0.19/hr for VpnGw1). Gateway and its Public IP deleted after a successful P2S connectivity test.
- 🧠 **Context:** VPN Gateway bills hourly regardless of usage; no later milestone (D–K) functionally requires an active tunnel. Certificates, VNet, and GatewaySubnet remain in place for a quick re-provision if a live demo is needed later.
- ⚠️ **Trade-off:** Re-provisioning takes ~30–45 minutes each time it's needed again — documented via screenshots instead of a persistently running resource.

### Resource Group strategy — per-layer separation

- ✅ **Decision:** Landing Zone uses three separate resource groups: `rg-hybridlab-network-dev`, `rg-hybridlab-workload-dev`, `rg-hybridlab-platform-dev`.
- 🧠 **Context:** Independent lifecycle per layer (e.g. rebuilding AKS shouldn't touch the VNet), and cleaner RBAC boundaries per layer.
- ⚠️ **Trade-off:** More Terraform resources to manage than a single shared RG, acceptable at this project's scale.

### Subnet address plan

- ✅ **Decision:** `snet-ingress-dev` (10.0.0.0/24), `snet-platform-dev` (10.0.1.0/24), `snet-workload-dev` (10.0.16.0/20), alongside the existing `GatewaySubnet` (10.0.255.0/27), all within the `10.0.0.0/16` VNet.
- 🧠 **Context:** Workload subnet sized generously (4096 IPs) to accommodate future AKS network plugin choice (Azure CNI vs kubenet), which isn't finalized until Milestone F.
- ⚠️ **Trade-off:** Large unused address ranges left between allocations intentionally, trading address efficiency for room to grow without renumbering.

### Ingress resource deferred to Milestone F

- ✅ **Decision:** No Load Balancer or Application Gateway is provisioned in Milestone E, despite `snet-ingress-dev` being ready.
- 🧠 **Context:** Both resource types require an existing backend (AKS) to be meaningfully configured and tested; provisioning them earlier would produce an unverifiable, backend-less resource.
- ⚠️ **Trade-off:** Landing Zone networking isn't fully "populated" yet — deferred until the real dependency (Milestone F) exists, consistent with the earlier GatewaySubnet-first pattern applied in reverse.

### AKS network plugin: Azure CNI Overlay

- ✅ **Decision:** Use Azure CNI Overlay (`network_plugin = "azure"`, `network_plugin_mode = "overlay"`) instead of kubenet or classic Azure CNI.
- 🧠 **Context:** Microsoft has announced kubenet's retirement (March 2028) and recommends Overlay as the default for new clusters — pods get IPs from a separate CIDR (`10.244.0.0/16`) rather than consuming VNet address space, avoiding the IP exhaustion risk of classic Azure CNI.
- ⚠️ **Trade-off:** Overlay is incompatible with Application Gateway Ingress Controller (AGIC), which narrowed the later ingress decision. The network plugin choice is also permanent — changing it requires recreating the cluster.

### Ingress architecture: NGINX Ingress Controller vs. native LoadBalancer Service

- ✅ **Decision:** Deploy NGINX Ingress Controller (via Helm, through Terraform's `helm_release` resource) rather than a native Kubernetes `LoadBalancer` Service per app.
- 🧠 **Context:** A shared entry point scales better if the project later adds more components, and provides a natural place for future TLS/HTTPS termination — both align with the project's goal of simulating a realistic corporate setup.
- ⚠️ **Trade-off:** The public Load Balancer NGINX provisions does not use the dedicated `snet-ingress-dev` subnet created in Milestone E — public Load Balancers aren't subnet-bound. That subnet remains unused unless an internal/private ingress is added later.

### Sample workload deployment method

- ✅ **Decision:** Deploy the sample application via plain Kubernetes YAML manifests (`kubectl apply`), not Terraform's `kubernetes` provider.
- 🧠 **Context:** Mirrors a realistic split between platform team (Terraform-managed infrastructure) and application team (workload deploys), and matches how a future CI/CD pipeline would typically operate.
- ⚠️ **Trade-off:** Terraform doesn't track these resources — `terraform destroy` won't clean them up; they must be removed separately with `kubectl delete`.

### Platform services layer: Key Vault, ACR, Log Analytics

- ✅ **Decision:** Provisioned Key Vault, Container Registry, and Log Analytics Workspace in `rg-hybridlab-platform-dev`, wired to AKS via role assignments and a diagnostic setting.
- 🧠 **Context:** Completes the Landing Zone's platform-services placeholder (created empty in Milestone E) with the three services the target architecture calls for.
- ⚠️ **Trade-off:** None significant — this is the core platform-services milestone as scoped from the start.

### On-prem VM recovery: VMware snapshot

- ✅ **Decision:** Took a VMware Workstation snapshot (`milestone-i-baseline`) of SRV-DC01 after Milestones D–H were complete.
- 🧠 **Context:** Answers the brief's "what happens if something is deleted or breaks" question for the on-prem side, mirroring the state-storage protection applied to the Azure side.
- ⚠️ **Trade-off:** A single snapshot captures one point in time — it isn't a rolling backup schedule, and reverting loses any changes made after the snapshot.

### Proving a VM recovery was real, not a manual fix

- ✅ **Decision:** Validated the snapshot revert by stopping DHCP, reverting to `milestone-i-baseline` without touching the service again, then confirming `Get-Service DHCPServer` returned `Running` with no manual intervention.
- 🧠 **Context:** A restarted service alone doesn't prove a backup mechanism works — the same result would appear whether someone reverted the snapshot or simply started the service by hand. Not touching the service after the break, then reading its state after revert, ties the outcome specifically to the snapshot.
- ⚠️ **Trade-off:** None — a verification method, not a design decision with downsides.

### CI/CD demo app: minimal custom build, not a re-tagged public image

- ✅ **Decision:** Built a small static site with an embedded version banner (Nginx + one `index.html`), replacing the public `nginxdemos/hello` image used since Milestone F.
- 🧠 **Context:** Re-tagging an existing public image into ACR would exercise the push/pull path but wouldn't prove the pipeline actually _builds_ anything from this repository's own source. The version banner (set to the short Git SHA at build time) also makes each deployment visually verifiable on the live site.
- ⚠️ **Trade-off:** One more small artifact (`app/`) to maintain, in exchange for a pipeline that's genuinely demonstrable rather than simulated.

---

## 📊 Monitoring

### AKS diagnostic settings scope

- ✅ **Decision:** Forward `kube-apiserver` and `kube-controller-manager` logs, plus `AllMetrics`, from AKS to the Log Analytics Workspace.
- 🧠 **Context:** These categories cover control-plane visibility without enabling every available category, keeping ingestion volume (and cost) predictable for a lab environment.
- ⚠️ **Trade-off:** Data-plane logs (e.g. `kube-audit`) aren't collected — sufficient for demonstrating the pipeline, not for full audit compliance.

### Container Insights enablement path

- ✅ **Decision:** Enabled AKS Container Insights via Terraform's `oms_agent` block, using MSI-based authentication.
- 🧠 **Context:** Node- and pod-level metrics were needed beyond the control-plane diagnostic logs already forwarded to Log Analytics.
- ⚠️ **Trade-off:** `oms_agent` deploys the agent pods but doesn't provision the Data Collection Rule the agent needs to send data anywhere — a gap the `az aks enable-addons monitoring` CLI path fills automatically but the raw Terraform resource does not.

### Manual Data Collection Rule pipeline

- ✅ **Decision:** Manually provisioned a Data Collection Endpoint, Data Collection Rule (`ContainerInsights` extension), and DCR-to-cluster association.
- 🧠 **Context:** Confirmed missing only after the Container Insights agent logged a silent onboarding failure — pods ran, but no data reached Log Analytics with no visible error in the Portal.
- ⚠️ **Trade-off:** Three extra resources to maintain instead of one CLI flag — more explicit, but more moving parts.

### Two-tier alerting: platform metric vs. log-based

- ✅ **Decision:** Split alerting into a platform metric alert (node CPU) and a Log Analytics scheduled query alert (pod failure states), sharing one Action Group.
- 🧠 **Context:** Metric alerts run independently of the Container Insights pipeline; log-based alerts depend on it — together they cover infrastructure- and application-level failures through separate paths, so one pipeline being down doesn't blind both.
- ⚠️ **Trade-off:** Two alerting mechanisms with different evaluation models (metric aggregation vs. KQL query count) to reason about, instead of one.

---

## 💰 Cost

### Alert rule set kept minimal

- ✅ **Decision:** Limited Milestone H alerting to one platform metric alert and one log-based alert, rather than a broader rule set.
- 🧠 **Context:** Each scheduled query rule carries a small ongoing cost; the goal was meaningful failure coverage for a lab environment, not exhaustive alerting.
- ⚠️ **Trade-off:** Narrower failure detection than a production environment would use.

### Subscription budget filtered by tag, not scoped to whole subscription

- ✅ **Decision:** Created a subscription-level Consumption Budget filtered to `project = hybridlab`, rather than an unfiltered subscription-wide budget or per-resource-group budgets.
- 🧠 **Context:** The subscription is shared with unrelated coursework (same concern as the Milestone J policy scope decision). A tag filter captures spend from all three of this project's resource groups in one place, without an unfiltered budget picking up other course projects' costs, and without needing three separate per-resource-group budgets.
- ⚠️ **Trade-off:** Depends entirely on tagging discipline — any hybridlab resource created without the `project` tag silently falls outside the budget's visibility. (Milestone J's "Require a tag on resources" policy on the platform resource group provides partial enforcement, but only within that one resource group.)

### Budget notifications: direct email, not the shared Action Group

- ✅ **Decision:** Used `contact_emails` on the budget's notification blocks instead of wiring it to the same Action Group used by Milestone H's alerts.
- 🧠 **Context:** A known issue in the `azurerm` provider causes `contact_groups` referencing an Action Group ID to trigger spurious "forces replacement" drift on subsequent plans. Using the same email address directly avoids the bug entirely, at the cost of one less-unified notification path.
- ⚠️ **Trade-off:** Budget alerts and infrastructure alerts (H) now go through two different mechanisms instead of one shared Action Group.

### Budget alert firing not verified end-to-end

- ✅ **Decision:** Verified the budget's configuration (amount, filter, thresholds, recipient) via the Portal, but did not verify an actual threshold-crossing notification firing.
- 🧠 **Context:** Azure Cost Management processes actual spend data with a reporting delay of up to 24 hours, unlike Milestone H's near-real-time metric/log alerts or Milestone J's immediate policy denials — there was no practical way to trigger and observe a real notification within the project's timeline.
- ⚠️ **Trade-off:** The budget's configuration is confirmed correct, but its end-to-end firing behavior is trusted rather than directly observed.

---

## 🔐 Governance & Policy

### Policy assignment scope: resource group, not subscription

- ✅ **Decision:** Assigned both governance policies at the `rg-hybridlab-platform-dev` resource group scope, not the subscription.
- 🧠 **Context:** The subscription is shared with unrelated coursework projects (other resource groups outside this project were visible in the Data Collection Rules view). A subscription-wide policy could unintentionally block or interfere with someone else's work.
- ⚠️ **Trade-off:** Only the platform resource group is protected — the network and workload resource groups aren't covered by these two policies.

### Built-in policy lookup via data source, not hardcoded IDs

- ✅ **Decision:** Used `data "azurerm_policy_definition" { display_name = "..." }` to resolve both built-in policies ("Allowed locations", "Require a tag on resources") instead of hardcoding their GUIDs.
- 🧠 **Context:** Built-in policy definition IDs are consistent across tenants in practice, but resolving by display name removes any risk of a typo'd or wrong-environment GUID silently pointing at the wrong policy.
- ⚠️ **Trade-off:** None significant — one extra data source per policy, negligible overhead.

### Two sources of deployment denial look identical at first glance

- ✅ **Decision:** Documented the distinction between `RequestDisallowedByAzure` (the subscription's own built-in region allowlist) and `RequestDisallowedByPolicy` (a custom policy assignment) as a debugging note.
- 🧠 **Context:** The first policy test used `westeurope`, which failed — but with `RequestDisallowedByAzure`, not `RequestDisallowedByPolicy`. The subscription itself only permits deployments to five regions (`germanywestcentral`, `spaincentral`, `uaenorth`, `italynorth`, `swedencentral`), independent of this project's own "Allowed locations" policy. Retesting with `germanywestcentral` (subscription-allowed, project-disallowed) correctly triggered the intended policy — and revealed both assigned policies evaluating and denying in the same response.
- ⚠️ **Trade-off:** None — a debugging insight, not a design trade-off, but worth documenting so a future reader doesn't misread the error code.
