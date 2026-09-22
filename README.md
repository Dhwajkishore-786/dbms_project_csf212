# Campus Clinic & Pharmacy Management System

## 1. Project Overview
A full-stack relational database application managing clinical consultations, electronic prescriptions, and pharmacy dispensary inventory with database-level integrity enforcement.

## 2. Architecture & Technology Stack
- **Database:** SQLite / PostgreSQL (Relational Engine, ACID constraints, Triggers, Views)
- **Backend:** Python FastAPI (Uvicorn ASGI, Connection Management)
- **Frontend:** Vanilla JS / HTML5 / CSS3 (Decoupled client interface)

## 3. High-Level Workflows
1. **Multi-Table Consultation Booking:** Atomic transaction checking doctor schedule availability, creating appointment records, and generating billing invoices.
2. **Pharmacy Inventory Guardrail:** Trigger-backed dispensary transaction blocking stockouts below order threshold and automatically adjusting live inventory.
3. **Departmental Financial Analytics:** Analytical reporting using grouping, aggregation views, and CTEs to compute clinic throughput.

## 4. Work Completed for Mid-Sem
- [x] Problem definition and explicit business constraints documented.
- [x] Formal ER model designed with cardinalities and participation constraints.
- [x] Relational schema mapped to 10 relations meeting 3NF/BCNF standards.
- [x] DDL script written with PK/FK, CHECK constraints, triggers, and analytical views.
- [ ] Part 2: Backend API endpoint routing and mock data generation (500+ records).

## 5. Team Contributions Breakdown
- **<Your Name>**: Domain requirements analysis, ER/EER modeling, relational normalization, and complete SQL DDL schema design.
- **<Teammate Name>**: Research on business rules, architecture documentation, and repository setup.
