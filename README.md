# Hybrid Azure Infrastructure

[English](#english) &nbsp;|&nbsp; [Deutsch](#deutsch)

---

<a name="english"></a>
## English

### 🚀 What is this?
- A hands-on final project connecting an on-premises Windows Server environment with Microsoft Azure
- Built through a secure hybrid network, provisioned with Terraform as the Infrastructure-as-Code layer
- 4-week deep dive into real-world hybrid infrastructure patterns

### 📍 Status
- Milestone B (On-Premises) complete — AD DS, DNS, DHCP configured
- Next up: Milestone C (Hybrid Connectivity)
- Every decision, with the reasoning behind it, lives in [`project-decisions.md`](./project-decisions.md)

### 🏗️ Architecture
- On-premises — Windows Server 2025 → AD DS · DNS · DHCP
- Identity bridge — Entra Connect
- Connectivity — Site-to-Site VPN Gateway
- Azure Landing Zone — VNet · Subnets · NSGs
- Workload — AKS running a sample app
- Platform services — Key Vault · ACR · Log Analytics
- Governance — Monitoring · Backup · Policy · Budget

> Full architecture diagram coming soon

### 🧰 Tech Stack
- Windows Server 2025
- Microsoft Azure
- Terraform
- Kubernetes (AKS)

### 📂 File Structure
```
hybrid-azure-infrastructure/
├── README.md
├── project-decisions.md      # every decision — the "why", not just the "what"
├── screenshots/              # setup steps, errors, working results — by milestone
├── terraform/
│   ├── env/                  # environment-specific variables (dev.tfvars)
│   └── modules/               # reusable modules
└── docs/                     # diagrams & extra notes
```
> `screenshots/` is one of the most important folders here — it's the visual proof behind every milestone.

### 📖 Documentation
- Every architectural choice, with context and trade-offs → [`project-decisions.md`](./project-decisions.md)

---

<a name="deutsch"></a>
## Deutsch

### 🚀 Worum geht's?
- Ein praxisnahes Abschlussprojekt: Verbindung eines On-Premises-Windows-Servers mit Microsoft Azure
- Sichere Hybrid-Verbindung, aufgebaut mit Terraform als Infrastructure-as-Code-Schicht
- 4 Wochen intensiver Einblick in echte Hybrid-Infrastruktur-Patterns

### 📍 Status
- Milestone B (On-Premises) abgeschlossen — AD DS, DNS, DHCP konfiguriert
- Als Nächstes: Milestone C (Hybrid Connectivity)
- Jede Entscheidung inklusive Begründung steht in [`project-decisions.md`](./project-decisions.md)

### 🏗️ Architektur
- On-Premises — Windows Server 2025 → AD DS · DNS · DHCP
- Identitätsbrücke — Entra Connect
- Verbindung — Site-to-Site VPN Gateway
- Azure Landing Zone — VNet · Subnets · NSGs
- Workload — AKS mit einer Beispiel-App
- Plattform-Dienste — Key Vault · ACR · Log Analytics
- Governance — Monitoring · Backup · Policy · Budget

> Vollständiges Architekturdiagramm folgt in Kürze

### 🧰 Tech-Stack
- Windows Server 2025
- Microsoft Azure
- Terraform
- Kubernetes (AKS)

### 📂 Dateistruktur
```
hybrid-azure-infrastructure/
├── README.md
├── project-decisions.md      # jede Entscheidung — das "Warum", nicht nur das "Was"
├── screenshots/              # Setup-Schritte, Fehler, Ergebnisse — pro Milestone
├── terraform/
│   ├── env/                  # umgebungsspezifische Variablen (dev.tfvars)
│   └── modules/               # wiederverwendbare Module
└── docs/                     # Diagramme & zusätzliche Notizen
```
> `screenshots/` ist einer der wichtigsten Ordner hier — der visuelle Beweis für jeden Milestone.

### 📖 Dokumentation
- Jede Architekturentscheidung inklusive Kontext und Trade-offs → [`project-decisions.md`](./project-decisions.md)
