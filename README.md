# Von FHIR zur Insight – Demos mit InterSystems IRIS for Health

FHIR® is the standard for healthcare data exchange —  
this repository contains example code and demo pages shown in the presentation  
**"Von FHIR zur Insight – Verarbeitung und Visualisierung von Gesundheitsdaten mit InterSystems IRIS"**.

---

## 💡 Overview

The examples demonstrate how developers can work directly with FHIR data inside  
**InterSystems IRIS for Health** — from ingestion to visualization.

| Example | Class | Description |
|----------|-------|-------------|
| **0 – FHIR-Proxy** | `HS.Local.Demo.FHIR.Utils.cls` | A simple CSP page acting as a FHIR proxy. Simplifies authentication and allows front-end demos to fetch FHIR bundles via REST. |
| **1 – PatientCard** | `HS.Local.Demo.FHIR.PatientCard.cls` | Displays patient data (`$everything`) in a compact dashboard with vitals, conditions, medications, allergies, and encounters. |
| **2 – BPTrend** | `HS.Local.Demo.FHIR.BPTrend.cls` | Visualizes systolic and diastolic blood pressure over time using Chart.js. |
| **3 – Timeline** | `HS.Local.Demo.FHIR.Timeline.cls` | Shows encounters, medications, and observations as a time-based view using vis-timeline. |
| **4 – RefGraph** | `HS.Local.Demo.FHIR.RefGraph.cls` | Displays references between FHIR resources as a network graph using vis-network. |
| **Landing** | `HS.Local.Demo.FHIR.Landing.cls` | Simple start page that lists all demos. |

---

## 🧰 Requirements

- **InterSystems IRIS for Health** 2023.3 or later  
- FHIR Repository (R4 or R4B) configured and running  
- Web Application (e.g. `/csp/healthshare/staging/fhir/r4`) with CSP enabled
- Web Application configured in `HS.Local.Demo.FHIR.Utils.#FhirRepo`  
- Example FHIR data (synthetic patient data recommended)

---

## ⚙️ Setup

1. Import and compile the class exports (`*.cls`) into your IRIS namespace.  
2. Compile the classes:
   ```objectscript
   ZN "USER"
   Do $SYSTEM.OBJ.Load("Demo/*.cls","ck")
   ```
3. Make sure your web app (e.g. /csp/user) allows access to the demo pages.

4. Open the landing page: http://localhost:52773/csp/user/HS.Local.Demo.FHIR.Landing.cls


## 🚀 How to Use

Each page calls the internal FHIR repository via Demo.FHIR.Utils.cls
and renders data client-side with JavaScript (Chart.js, vis-timeline, vis-network).

These examples are designed to:
- Explore FHIR data structures directly in the browser
- Debug and understand resource relationships
- Prototype visualizations for SMART-on-FHIR or analytics apps

## 🧾 Disclaimer

The code and examples in this repository are intended for demonstration and educational purposes only.

They are not production-ready and should not be used with real patient data.

All data used is synthetic.

This content is community-driven and not officially supported by InterSystems.

## 🧩 License

MIT License — see LICENSE

## 👨‍💻 About

These examples accompany the developer talk:

“Von FHIR zur Insight – Verarbeitung und Visualisierung von Gesundheitsdaten mit InterSystems IRIS”
Presented at Symposium 2025 by Brandon Thomas