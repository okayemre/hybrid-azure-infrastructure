# Hybrid Azure Infrastructure

![Windows Server](https://img.shields.io/badge/Windows_Server_2025-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Microsoft Azure](https://img.shields.io/badge/Microsoft_Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Status](https://img.shields.io/badge/Status-In_Progress_%F0%9F%9F%A1-yellow?style=for-the-badge)

---

**[English](#english)** &nbsp;·&nbsp; **[Deutsch](#deutsch)**

---

# English

<a name="english"></a>

An end-to-end, hands-on build of a hybrid IT infrastructure — an on-premises Windows Server environment connected to Microsoft Azure through a secure network tunnel and a shared identity layer. Built solo as a 4-week final project (Abschlussprojekt), with Terraform as the Infrastructure-as-Code layer for every repeatable Azure resource.

> 📄 **Original assignment (German):** [docs/Abschlussprojekt_Hybrid_Infrastruktur.pdf](docs/Abschlussprojekt_Hybrid_Infrastruktur.pdf)

## The Approach

Most real companies aren't "all cloud" or "all on-prem" — existing systems can't move overnight, some data has to stay local, and migrations happen gradually. This project rebuilds that reality at a small scale: an on-prem Active Directory environment that keeps running, a workload in Azure that needs the same identities, and a secure tunnel connecting the two — plus the operational layer (monitoring, backup, policy, budget) a real environment would need around it.

## 📋 Table of Contents

| | Milestone | Topic | Status |
|--|-----------|-------|--------|
| 🧱 | [Foundations](#foundations) | Terraform basics, naming, environment setup | ✅ |
| 🖥️ | [Milestone B: On-Premises Server](#milestone-b-on-premises-server) | AD DS, DNS, DHCP, OU structure | ✅ |
| 🔌 | [Milestone C: Hybrid Connectivity](#milestone-c-hybrid-connectivity) | VNet, GatewaySubnet, Point-to-Site VPN | ✅ |
| 🔐 | [Milestone D: Hybrid Identity](#milestone-d-hybrid-identity) | Entra Connect, PHS, UPN suffix | ✅ |
| 🏗️ | [Milestone E: Landing Zone](#milestone-e-landing-zone) | Resource Groups, VNet subnets, NSGs | ✅ |
| ☸️ | Milestone F: Workload (AKS) | Sample app on AKS | ⏳ |
| 🔑 | Milestone G: Platform Services | Key Vault, ACR, Log Analytics | ⏳ |
| 📊 | Milestone H–K: Governance & Extensions | Monitoring, Backup, Policy, Budget | ⏳ |

## 🏗️ Infrastructure Overview

| Resource | Name | Configuration |
|---|---|---|
| Domain Controller | SRV-DC01 | Windows Server 2025, VMware Workstation, static IP 192.168.0.15 |
| AD Forest / Domain | hybridlab.local | NetBIOS `HYBRIDLAB`, OU `HybridLab-Staff` |
| Hybrid Identity Sync | Microsoft Entra Connect | Password Hash Sync, OU-scoped |
| Resource Group (Network) | `rg-hybridlab-network-dev` | Sweden Central |
| Resource Group (Workload) | `rg-hybridlab-workload-dev` | Sweden Central, empty — pending Milestone F |
| Resource Group (Platform) | `rg-hybridlab-platform-dev` | Sweden Central, empty — pending Milestone G |
| Virtual Network | `vnet-hybridlab-dev` | `10.0.0.0/16` |
| Subnets | GatewaySubnet · snet-ingress-dev · snet-platform-dev · snet-workload-dev | `10.0.255.0/27` · `10.0.0.0/24` · `10.0.1.0/24` · `10.0.16.0/20` |
| Network Security Groups | nsg-ingress-dev · nsg-platform-dev · nsg-workload-dev | One-to-one with functional subnets |

## 🗺️ Architecture Diagram

```mermaid
flowchart TB
    subgraph OnPrem["On-Premises — VMware Workstation"]
        DC[SRV-DC01<br/>Windows Server 2025<br/>AD DS · DNS · DHCP]
    end

    subgraph Identity["Hybrid Identity"]
        EC[Entra Connect<br/>PHS, OU-scoped]
    end

    subgraph LandingZone["Azure Landing Zone — Sweden Central"]
        subgraph NetRG["rg-hybridlab-network-dev"]
            VNET[vnet-hybridlab-dev — 10.0.0.0/16]
            GW[GatewaySubnet]
            ING[snet-ingress-dev]
            PLAT[snet-platform-dev]
            WORK[snet-workload-dev]
        end
        subgraph WorkRG["rg-hybridlab-workload-dev"]
            AKS[AKS — Milestone F]
        end
        subgraph PlatRG["rg-hybridlab-platform-dev"]
            KV[Key Vault / ACR / Log Analytics — Milestone G]
        end
    end

    DC -->|sync| EC
    DC -.->|Point-to-Site, on demand| GW
    VNET --- GW
    VNET --- ING
    VNET --- PLAT
    VNET --- WORK
    WORK -.-> AKS
    PLAT -.-> KV
```

## Foundations

<a name="foundations"></a>

> 💡 Before touching real infrastructure, this phase built the Terraform skills and project conventions everything else depends on.

**Steps performed:**
- Completed a structured Terraform course — providers, state, modules, remote backends, `count`/`for_each`
- Set up the Terraform project skeleton: Azure Blob Storage remote state backend, `ARM_SUBSCRIPTION_ID` environment-variable authentication, pinned provider (`azurerm ~> 5.1.0`)
- Defined project naming conventions: app name `hybridlab`, environment `dev`, `random_string` suffixes for globally-unique resources
- Established the Terraform vs. Portal split — repeatable resources (Landing Zone, AKS, Key Vault, ACR, Log Analytics) via Terraform; wizard-heavy, one-time resources (VPN Gateway) via Portal

> 🔑 **Key insight — course material and current documentation can silently diverge.** The Terraform course used an older `azurerm` provider version than this project's pinned `~> 5.1.0`, causing attribute-name mismatches (e.g. `enable_rbac_authorization` vs. `rbac_authorization_enabled`) that only surface at `terraform plan` time — always cross-check attribute names against current provider docs, not just course notes.

⬆ [Back to top](#english)

---

## Milestone B: On-Premises Server

<a name="milestone-b-on-premises-server"></a>

> 💡 A hybrid environment needs something to be hybrid *with* — this milestone built the on-premises half: a domain controller providing identity, name resolution, and address assignment.

**Steps performed:**
- Created a Windows Server 2025 VM (4 GB RAM, 2 vCPU) in VMware Workstation, network adapter set to Bridged to avoid double-NAT ahead of Milestone C's VPN tunnel
- Assigned static IP `192.168.0.15`, excluded from the home router's DHCP pool to prevent conflicts
- Installed AD DS, promoted the server to a new forest `hybridlab.local` (NetBIOS `HYBRIDLAB`)
- Verified the DNS role (auto-installed alongside AD DS)
- Installed the DHCP role, created and authorized scope `192.168.0.100`–`192.168.0.150` — left inactive since the home router's own DHCP pool already covers most of the subnet
- Created OU `HybridLab-Staff` with a test user representing a standard employee account

| | |
|--|--|
| ![Active Directory Users and Computers showing the HybridLab-Staff OU and test user](screenshots/b-ad-ou-user-structure.png) | ![DHCP console showing the configured and authorized scope](screenshots/b-dhcp-role-configured.png) |
| *HybridLab-Staff OU and test user* | *DHCP scope — configured and authorized* |

![Domain controller verification showing the promoted server and domain details](screenshots/b-domain-controller-verification.png)

*SRV-DC01 — successfully promoted to domain controller for hybridlab.local*

> 🔑 **Key insight — promoting a server to a domain controller installs DNS automatically, but it still needs verifying.** AD DS and DNS are often treated as two separate installation steps; in practice, promoting the forest root installs and configures DNS as part of the same wizard — the role still has to be explicitly checked afterward (zones, records) rather than assumed correct.

⬆ [Back to top](#english)

---

## Milestone C: Hybrid Connectivity

<a name="milestone-c-hybrid-connectivity"></a>

> 💡 Azure VPN Gateway requires a VNet with a `GatewaySubnet` before it can exist — so this milestone's networking piece was provisioned via Terraform ahead of the full Landing Zone (Milestone E).

**Steps performed:**
- Provisioned a minimal VNet (`10.0.0.0/16`) with a `GatewaySubnet` (`10.0.255.0/27`) via Terraform
- Discovered the home ISP uses DS-Lite (no public IPv4) — pivoted from a planned Site-to-Site to a Point-to-Site VPN
- Generated a self-signed root/child certificate pair on SRV-DC01, configured certificate-based P2S authentication
- Deployed a Basic SKU VPN Gateway, verified a successful P2S connection from SRV-DC01
- Deleted the Gateway and its Public IP after verification — Gateway bills hourly regardless of usage, and no later milestone needs an active tunnel

| | |
|--|--|
| ![Terraform apply output creating the VNet and GatewaySubnet](screenshots/c-network-terraform-apply.png) | ![VPN Gateway review and create screen in the Azure Portal](screenshots/c-vpn-gateway-review-create.png) |
| *VNet + GatewaySubnet — Terraform apply* | *VPN Gateway — Portal deployment* |
| ![Point-to-Site VPN client configuration download](screenshots/c-p2s-vpn-configuration.png) | ![Successful Point-to-Site VPN connection status](screenshots/c-p2s-vpn-connected.png) |
| *P2S client configuration* | *P2S connection — Connected* |

> 🔑 **Key insight — cloud architecture decisions can be forced by home-network reality.** Site-to-Site VPN was the original plan, but DS-Lite (no public IPv4) made it technically impossible. Point-to-Site, which initiates outbound from the server, sidesteps the problem entirely.

⬆ [Back to top](#english)

---

## Milestone D: Hybrid Identity

<a name="milestone-d-hybrid-identity"></a>

> 💡 A hybrid environment isn't really hybrid until the same person can sign in on-prem and in the cloud with one identity — this milestone built that bridge.

**Steps performed:**
- Installed Microsoft Entra Connect on SRV-DC01
- Hit an `AADSTS50020` sign-in error using the tenant's original MSA-linked owner account — created a dedicated cloud-only Global Administrator account instead
- Temporarily disabled IE Enhanced Security Configuration on SRV-DC01 to allow the wizard's embedded sign-in browser to reach `login.microsoftonline.com`
- Chose Password Hash Synchronization (PHS) over Pass-through Authentication (PTA) — no extra on-prem agent, keeps working if SRV-DC01 goes offline
- Scoped sync to only the `HybridLab-Staff` OU, excluding default/system AD objects
- Fixed a UPN suffix mismatch: added the tenant's `*.onmicrosoft.com` domain as an alternate UPN suffix in on-prem AD, updated the test user's UPN
- Ran the first sync, verified the user appeared in Microsoft Entra ID, and confirmed hybrid sign-in success

| | |
|--|--|
| ![Entra Connect sync status showing a successful synchronization run](screenshots/d-entra-connect-sync-status.png) | ![Microsoft Entra ID users list showing the synced on-prem user](screenshots/d-entra-id-users-synced.png) |
| *Entra Connect — sync status* | *Entra ID — synced user visible* |

![Successful sign-in using the same hybrid identity](screenshots/d-hybrid-signin-success.png)

*Hybrid sign-in — same identity, on-prem and cloud*

> 🔑 **Key insight — a domain's internal name and its cloud-verifiable identity aren't automatically the same thing.** `hybridlab.local` works fine for on-prem authentication, but Entra ID silently rejects sign-in for any UPN using an unverified suffix. The fix isn't renaming the domain — it's adding a UPN alternate suffix, which only changes login names, not machine or domain names.

⬆ [Back to top](#english)

---

## Milestone E: Landing Zone

<a name="milestone-e-landing-zone"></a>

> 💡 Azure Landing Zones separate resources by function — network, workload, platform — so each layer can be rebuilt or governed independently. This milestone built that separation on top of the VNet already provisioned in Milestone C.

**Steps performed:**
- Split the Landing Zone across three resource groups: `rg-hybridlab-network-dev`, `rg-hybridlab-workload-dev`, `rg-hybridlab-platform-dev`
- Extended the existing Terraform network module with a `for_each`-based pattern, provisioning three functional subnets (ingress, platform, workload) from a single map variable
- Sized the workload subnet generously (`/20`, 4096 IPs) to accommodate an as-yet-undecided AKS network plugin (Azure CNI vs. kubenet)
- Created one Network Security Group per functional subnet, associated via `azurerm_subnet_network_security_group_association`
- Applied a shared `common_tags` local (project, environment, managed_by) across all taggable resources
- Deliberately deferred provisioning a Load Balancer / Application Gateway in the ingress subnet — no backend (AKS) exists yet to meaningfully configure or test one

![Azure Portal Subnets view showing all four subnets with their associated NSGs](screenshots/e-subnets-nsg-overview.png)

*VNet subnets — GatewaySubnet plus three functional subnets, each with its own NSG*

> 🔑 **Key insight — a `for_each` map turns a repeatable pattern into a single source of truth.** Three subnets, three NSGs, and three associations all iterate over the same `subnets` variable — adding a fourth functional subnet later means adding one map entry, not copy-pasting six resource blocks.

⬆ [Back to top](#english)

---

## Roadmap

- **Milestone F — Workload:** Deploy AKS into `rg-hybridlab-workload-dev`, run a sample app, connect the deferred ingress resource
- **Milestone G — Platform Services:** Key Vault, ACR, Log Analytics into `rg-hybridlab-platform-dev`
- **Milestone H–K — Governance & Extensions:** Monitoring, backup, policy, budget, and optional stretch goals

⬆ [Back to top](#english)

---

<a name="deutsch"></a>
# Deutsch

Ein praxisnahes, selbst umgesetztes Projekt: eine hybride IT-Infrastruktur, bestehend aus einem On-Premises-Windows-Server, der über einen sicheren Netzwerktunnel und eine gemeinsame Identitätsebene mit Microsoft Azure verbunden ist. Als vierwöchiges Abschlussprojekt allein umgesetzt, mit Terraform als Infrastructure-as-Code-Schicht für jede wiederholbare Azure-Ressource.

> 📄 **Originalaufgabenstellung:** [docs/Abschlussprojekt_Hybrid_Infrastruktur.pdf](docs/Abschlussprojekt_Hybrid_Infrastruktur.pdf)

## Der Ansatz

Die wenigsten Unternehmen sind rein "Cloud" oder rein "On-Premises" — bestehende Systeme lassen sich nicht über Nacht verschieben, manche Daten müssen lokal bleiben, Migrationen passieren schrittweise. Dieses Projekt bildet genau das im Kleinen nach: eine On-Premises-Active-Directory-Umgebung, die weiterläuft, eine Azure-Workload, die dieselben Identitäten braucht, und ein sicherer Tunnel, der beide verbindet — dazu die Betriebsebene (Monitoring, Backup, Policy, Budget), die eine echte Umgebung drumherum bräuchte.

## 📋 Inhaltsverzeichnis

| | Milestone | Thema | Status |
|--|-----------|-------|--------|
| 🧱 | [Grundlagen](#grundlagen) | Terraform-Basiswissen, Namenskonvention, Projekt-Setup | ✅ |
| 🖥️ | [Milestone B: On-Premises-Server](#milestone-b-on-premises-server-de) | AD DS, DNS, DHCP, OU-Struktur | ✅ |
| 🔌 | [Milestone C: Hybrid-Konnektivität](#milestone-c-hybrid-konnektivitat) | VNet, GatewaySubnet, Point-to-Site-VPN | ✅ |
| 🔐 | [Milestone D: Hybrid-Identität](#milestone-d-hybrid-identitat) | Entra Connect, PHS, UPN-Suffix | ✅ |
| 🏗️ | [Milestone E: Landing Zone](#milestone-e-landing-zone-de) | Resource Groups, VNet-Subnetze, NSGs | ✅ |
| ☸️ | Milestone F: Workload (AKS) | Beispiel-App auf AKS | ⏳ |
| 🔑 | Milestone G: Plattform-Dienste | Key Vault, ACR, Log Analytics | ⏳ |
| 📊 | Milestone H–K: Governance & Erweiterungen | Monitoring, Backup, Policy, Budget | ⏳ |

## 🏗️ Infrastruktur-Übersicht

| Ressource | Name | Konfiguration |
|---|---|---|
| Domain Controller | SRV-DC01 | Windows Server 2025, VMware Workstation, statische IP 192.168.0.15 |
| AD-Forest / Domäne | hybridlab.local | NetBIOS `HYBRIDLAB`, OU `HybridLab-Staff` |
| Hybrid-Identitätssynchronisation | Microsoft Entra Connect | Password Hash Sync, OU-eingeschränkt |
| Resource Group (Network) | `rg-hybridlab-network-dev` | Sweden Central |
| Resource Group (Workload) | `rg-hybridlab-workload-dev` | Sweden Central, leer — Milestone F ausstehend |
| Resource Group (Platform) | `rg-hybridlab-platform-dev` | Sweden Central, leer — Milestone G ausstehend |
| Virtual Network | `vnet-hybridlab-dev` | `10.0.0.0/16` |
| Subnetze | GatewaySubnet · snet-ingress-dev · snet-platform-dev · snet-workload-dev | `10.0.255.0/27` · `10.0.0.0/24` · `10.0.1.0/24` · `10.0.16.0/20` |
| Network Security Groups | nsg-ingress-dev · nsg-platform-dev · nsg-workload-dev | Je 1:1 mit funktionalem Subnetz |

> Das Architekturdiagramm im englischen Abschnitt oben gilt sprachübergreifend — Azure-Ressourcennamen bleiben ohnehin auf Englisch.

## Grundlagen

<a name="grundlagen"></a>

> 💡 Bevor echte Infrastruktur angefasst wurde, baute diese Phase das Terraform-Wissen und die Projektkonventionen auf, von denen alles Weitere abhängt.

**Durchgeführte Schritte:**
- Strukturierten Terraform-Kurs abgeschlossen — Provider, State, Module, Remote Backends, `count`/`for_each`
- Terraform-Projektgerüst aufgesetzt: Remote-State-Backend in Azure Blob Storage, Authentifizierung über `ARM_SUBSCRIPTION_ID`-Umgebungsvariable, fixierte Provider-Version (`azurerm ~> 5.1.0`)
- Namenskonvention festgelegt: App-Name `hybridlab`, Umgebung `dev`, `random_string`-Suffixe für global eindeutige Ressourcen
- Terraform-vs.-Portal-Aufteilung definiert — wiederholbare Ressourcen (Landing Zone, AKS, Key Vault, ACR, Log Analytics) über Terraform; einmalige, assistentenlastige Ressourcen (VPN Gateway) über das Portal

> 🔑 **Erkenntnis — Kursmaterial und aktuelle Dokumentation können auseinanderlaufen.** Der Terraform-Kurs nutzte eine ältere `azurerm`-Provider-Version als die im Projekt fixierte `~> 5.1.0`, was zu abweichenden Attributnamen führte (z. B. `enable_rbac_authorization` vs. `rbac_authorization_enabled`) — sichtbar erst bei `terraform plan`. Attributnamen daher immer gegen die aktuelle Provider-Dokumentation prüfen, nicht nur gegen Kursnotizen.

⬆ [Nach oben](#deutsch)

---

## Milestone B: On-Premises-Server

<a name="milestone-b-on-premises-server-de"></a>

> 💡 Eine hybride Umgebung braucht eine Gegenseite, mit der sie hybrid sein kann — dieser Milestone baute die On-Premises-Hälfte: einen Domain Controller für Identität, Namensauflösung und Adressvergabe.

**Durchgeführte Schritte:**
- Windows-Server-2025-VM erstellt (4 GB RAM, 2 vCPU) in VMware Workstation, Netzwerkadapter auf Bridged gestellt, um Double-NAT vor dem VPN-Tunnel in Milestone C zu vermeiden
- Statische IP `192.168.0.15` vergeben, aus dem DHCP-Pool des Heimrouters ausgeschlossen, um Konflikte zu vermeiden
- AD DS installiert, Server zu neuem Forest `hybridlab.local` (NetBIOS `HYBRIDLAB`) heraufgestuft
- DNS-Rolle verifiziert (wird bei AD DS automatisch mitinstalliert)
- DHCP-Rolle installiert, Scope `192.168.0.100`–`192.168.0.150` angelegt und autorisiert — inaktiv belassen, da der Heimrouter bereits den Großteil des Subnetzes per DHCP abdeckt
- OU `HybridLab-Staff` mit einem Testbenutzer angelegt, der einen typischen Mitarbeiter-Account repräsentiert

| | |
|--|--|
| ![Active Directory-Benutzer und -Computer mit der HybridLab-Staff-OU und dem Testbenutzer](screenshots/b-ad-ou-user-structure.png) | ![DHCP-Konsole mit konfiguriertem und autorisiertem Scope](screenshots/b-dhcp-role-configured.png) |
| *HybridLab-Staff-OU und Testbenutzer* | *DHCP-Scope — konfiguriert und autorisiert* |

![Domain-Controller-Verifikation mit dem heraufgestuften Server und den Domänendetails](screenshots/b-domain-controller-verification.png)

*SRV-DC01 — erfolgreich zum Domain Controller für hybridlab.local heraufgestuft*

> 🔑 **Erkenntnis — die Heraufstufung zum Domain Controller installiert DNS automatisch, muss aber trotzdem geprüft werden.** AD DS und DNS wirken wie zwei getrennte Installationsschritte; tatsächlich installiert und konfiguriert der Assistent DNS direkt mit — die Rolle muss danach trotzdem explizit verifiziert werden (Zonen, Einträge), statt als korrekt vorausgesetzt zu werden.

⬆ [Nach oben](#deutsch)

---

## Milestone C: Hybrid-Konnektivität

<a name="milestone-c-hybrid-konnektivitat"></a>

> 💡 Ein Azure VPN Gateway benötigt zwingend ein VNet mit einem `GatewaySubnet`, bevor es existieren kann — der Netzwerkanteil dieses Milestones wurde deshalb per Terraform vorgezogen, noch vor der vollständigen Landing Zone (Milestone E).

**Durchgeführte Schritte:**
- Minimales VNet (`10.0.0.0/16`) mit `GatewaySubnet` (`10.0.255.0/27`) per Terraform bereitgestellt
- Festgestellt, dass der heimische Internetanbieter DS-Lite nutzt (keine öffentliche IPv4) — Wechsel vom geplanten Site-to-Site zu Point-to-Site-VPN
- Selbstsigniertes Root-/Child-Zertifikatspaar auf SRV-DC01 erzeugt, zertifikatsbasierte P2S-Authentifizierung konfiguriert
- VPN Gateway der Basic-SKU bereitgestellt, erfolgreiche P2S-Verbindung von SRV-DC01 verifiziert
- Gateway und zugehörige Public IP nach der Verifikation gelöscht — das Gateway wird stundenweise abgerechnet, unabhängig von der Nutzung, und kein späterer Milestone benötigt einen aktiven Tunnel

| | |
|--|--|
| ![Terraform-Apply-Ausgabe bei der Erstellung von VNet und GatewaySubnet](screenshots/c-network-terraform-apply.png) | ![VPN-Gateway-Übersichtsseite im Azure Portal](screenshots/c-vpn-gateway-review-create.png) |
| *VNet + GatewaySubnet — Terraform Apply* | *VPN Gateway — Bereitstellung im Portal* |
| ![Download der Point-to-Site-VPN-Client-Konfiguration](screenshots/c-p2s-vpn-configuration.png) | ![Erfolgreicher Point-to-Site-VPN-Verbindungsstatus](screenshots/c-p2s-vpn-connected.png) |
| *P2S-Client-Konfiguration* | *P2S-Verbindung — Verbunden* |

> 🔑 **Erkenntnis — Cloud-Architekturentscheidungen können durch die Realität des Heimnetzwerks erzwungen werden.** Site-to-Site-VPN war der ursprüngliche Plan, aber DS-Lite (keine öffentliche IPv4) machte ihn technisch unmöglich. Point-to-Site, das den Verbindungsaufbau vom Server aus initiiert, umgeht das Problem vollständig.

⬆ [Nach oben](#deutsch)

---

## Milestone D: Hybrid-Identität

<a name="milestone-d-hybrid-identitat"></a>

> 💡 Eine hybride Umgebung ist erst wirklich hybrid, wenn sich dieselbe Person on-premises und in der Cloud mit einer Identität anmelden kann — dieser Milestone baute genau diese Brücke.

**Durchgeführte Schritte:**
- Microsoft Entra Connect auf SRV-DC01 installiert
- Anmeldefehler `AADSTS50020` mit dem ursprünglichen, MSA-verknüpften Tenant-Owner-Account erhalten — stattdessen einen dedizierten Cloud-only-Global-Administrator-Account angelegt
- IE Enhanced Security Configuration auf SRV-DC01 temporär deaktiviert, damit der eingebettete Anmelde-Browser des Assistenten `login.microsoftonline.com` erreichen konnte
- Password Hash Synchronization (PHS) statt Pass-through Authentication (PTA) gewählt — kein zusätzlicher On-Premises-Agent nötig, funktioniert weiter, falls SRV-DC01 offline geht
- Synchronisation auf die OU `HybridLab-Staff` beschränkt, Standard-/System-AD-Objekte ausgeschlossen
- UPN-Suffix-Konflikt behoben: `*.onmicrosoft.com`-Domäne des Tenants als alternatives UPN-Suffix im On-Premises-AD hinzugefügt, UPN des Testbenutzers entsprechend aktualisiert
- Erste Synchronisation ausgeführt, Benutzer in Microsoft Entra ID verifiziert, erfolgreiche hybride Anmeldung bestätigt

| | |
|--|--|
| ![Entra-Connect-Synchronisationsstatus mit erfolgreichem Sync-Lauf](screenshots/d-entra-connect-sync-status.png) | ![Microsoft-Entra-ID-Benutzerliste mit dem synchronisierten On-Premises-Benutzer](screenshots/d-entra-id-users-synced.png) |
| *Entra Connect — Synchronisationsstatus* | *Entra ID — synchronisierter Benutzer sichtbar* |

![Erfolgreiche Anmeldung mit derselben hybriden Identität](screenshots/d-hybrid-signin-success.png)

*Hybride Anmeldung — dieselbe Identität, on-premises und in der Cloud*

> 🔑 **Erkenntnis — der interne Name einer Domäne und ihre cloud-verifizierbare Identität sind nicht automatisch dasselbe.** `hybridlab.local` funktioniert einwandfrei für die On-Premises-Authentifizierung, aber Entra ID lehnt die Anmeldung für jedes UPN mit einem nicht verifizierten Suffix stillschweigend ab. Die Lösung ist nicht die Umbenennung der Domäne — sondern ein alternatives UPN-Suffix, das ausschließlich den Anmeldenamen ändert, nicht den Rechner- oder Domänennamen.

⬆ [Nach oben](#deutsch)

---

## Milestone E: Landing Zone

<a name="milestone-e-landing-zone-de"></a>

> 💡 Azure Landing Zones trennen Ressourcen nach Funktion — Network, Workload, Platform —, damit jede Schicht unabhängig neu aufgebaut oder verwaltet werden kann. Dieser Milestone baute diese Trennung auf dem bereits in Milestone C bereitgestellten VNet auf.

**Durchgeführte Schritte:**
- Landing Zone auf drei Resource Groups aufgeteilt: `rg-hybridlab-network-dev`, `rg-hybridlab-workload-dev`, `rg-hybridlab-platform-dev`
- Bestehendes Terraform-Netzwerkmodul um ein `for_each`-basiertes Muster erweitert, das drei funktionale Subnetze (Ingress, Platform, Workload) aus einer einzigen Map-Variable erzeugt
- Workload-Subnetz großzügig dimensioniert (`/20`, 4096 IPs), um ein noch nicht festgelegtes AKS-Netzwerk-Plugin (Azure CNI vs. kubenet) zu berücksichtigen
- Pro funktionalem Subnetz eine eigene Network Security Group erstellt, verknüpft über `azurerm_subnet_network_security_group_association`
- Gemeinsames `common_tags`-Local (Project, Environment, Managed_by) auf alle taggbaren Ressourcen angewendet
- Bereitstellung eines Load Balancers/Application Gateways im Ingress-Subnetz bewusst zurückgestellt — es existiert noch kein Backend (AKS), um eine solche Ressource sinnvoll zu konfigurieren oder zu testen

![Azure-Portal-Subnetzansicht mit allen vier Subnetzen und den zugehörigen NSGs](screenshots/e-subnets-nsg-overview.png)

*VNet-Subnetze — GatewaySubnet plus drei funktionale Subnetze, jeweils mit eigener NSG*

> 🔑 **Erkenntnis — eine `for_each`-Map macht aus einem sich wiederholenden Muster eine einzige Quelle der Wahrheit.** Drei Subnetze, drei NSGs und drei Assoziationen iterieren alle über dieselbe `subnets`-Variable — ein viertes funktionales Subnetz später hinzuzufügen bedeutet einen zusätzlichen Map-Eintrag, kein Copy-Paste von sechs Resource-Blöcken.

⬆ [Nach oben](#deutsch)

---

## Roadmap

- **Milestone F — Workload:** AKS in `rg-hybridlab-workload-dev` bereitstellen, Beispiel-App betreiben, zurückgestellte Ingress-Ressource anbinden
- **Milestone G — Plattform-Dienste:** Key Vault, ACR, Log Analytics in `rg-hybridlab-platform-dev`
- **Milestone H–K — Governance & Erweiterungen:** Monitoring, Backup, Policy, Budget sowie optionale Erweiterungsziele

⬆ [Nach oben](#deutsch)

---

## 🧠 Wichtigste Erkenntnisse

| # | Erkenntnis | Warum es wichtig ist |
|---|---------|-----------------|
| 1 | 🧱 Provider-Versionsabweichungen führen zu stillen Konflikten | Kursmaterial vs. fixierte `azurerm ~> 5.1.0` — immer gegen aktuelle Doku prüfen |
| 2 | 🖥️ AD-DS-Heraufstufung installiert DNS automatisch mit | Trotzdem explizite Verifikation nach der Installation nötig |
| 3 | 🔌 Die Realität des Heimnetzwerks kann den Lehrbuch-Plan überstimmen | DS-Lite erzwang den Wechsel von Site-to-Site zu Point-to-Site |
| 4 | 🔐 Domänenname ≠ cloud-verifizierbare Identität | Alternatives UPN-Suffix behebt die Anmeldung, ohne die Domäne umzubenennen |
| 5 | 🏗️ `for_each` macht aus Wiederholung eine einzige Quelle der Wahrheit | Eine Map-Variable steuert Subnetze, NSGs und Assoziationen gemeinsam |

## 🛠️ Tools & Services

![Windows Server](https://img.shields.io/badge/Windows_Server_2025-0078D4?style=flat-square&logo=windows&logoColor=white)
![VMware](https://img.shields.io/badge/VMware_Workstation-607078?style=flat-square&logo=vmware&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)
![Azure Portal](https://img.shields.io/badge/Azure_Portal-0078D4?style=flat-square&logo=microsoft-azure&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-0078D4?style=flat-square&logo=microsoft-azure&logoColor=white)
![Virtual Network](https://img.shields.io/badge/Virtual_Network-0078D4?style=flat-square&logo=microsoft-azure&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active_Directory-0078D4?style=flat-square&logo=microsoft&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)

## 📁 Repository-Struktur

```
hybrid-azure-infrastructure/
├── README.md
├── project-decisions.md
├── docs/
│   └── Abschlussprojekt_Hybrid_Infrastruktur.pdf
├── screenshots/
│   ├── b-ad-ou-user-structure.png
│   ├── b-dhcp-role-configured.png
│   ├── b-domain-controller-verification.png
│   ├── c-network-terraform-apply.png
│   ├── c-vpn-gateway-review-create.png
│   ├── c-p2s-vpn-configuration.png
│   ├── c-p2s-vpn-connected.png
│   ├── d-entra-connect-sync-status.png
│   ├── d-entra-id-users-synced.png
│   ├── d-hybrid-signin-success.png
│   └── e-subnets-nsg-overview.png
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── versions.tf
    ├── env/
    │   └── dev.tfvars
    └── modules/
        └── network/
            ├── main.tf
            ├── variables.tf
            └── outputs.tf
```

---

> *DCI Weiterbildung – IT System Administrator & Cloud Engineer · Sweden Central · Azure for Students Subscription · August 2026*
