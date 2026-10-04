# MediQore: Final Scope (FYP-I, Fall 2026)

> Markdown copy of the approved scope document `MediQore_FYP-1_Final_Scope_Fall_2026.docx`, made so the scope can be searched and read inside the repo. The text and tables are copied unchanged; the images (logo, Gantt chart, scanned plagiarism report) are left out. If this copy and the Word document ever differ, the Word document wins, except for the approved amendments listed below, which the Word document has not caught up with yet.

## Amendments after approval

These changes were approved by the supervisor after the scope was signed off. They apply on top of the Word document; update the Word document to match before final submission. Amended text below is marked *(A1)*.

| No. | Date | Change | Approved by | Record |
|---|---|---|---|---|
| A1 | 2026-10-04 | The LHW app gets an Urdu/English language switch (new M1 FE-4). Urdu stays the default. Voice guidance works only in Urdu (M3 FE-3, LI-6). shared_preferences joins the Tools table to keep the choice on the phone. | Ma'am Sajida Kalsoom (supervisor), as reported by the team | [Decision 0005](decisions/0005-language-switch.md) |

**COMSATS University Islamabad (CUI)** · Project Proposal for **MediQore** (An AI-Assisted, Offline-Ready Digital Health Platform for Lady Health Workers in Pakistan) · Version 1.0

- **By:** Muhammad Zain Abbas (CIIT/FA23-BCS-079/ISB), Zain Ali (CIIT/FA23-BCS-138/ISB)
- **Supervisor:** Ma'am Sajida Kalsoom
- **Programme:** Bachelor of Science in Computer Science (2023 – 2027)
- **Project category:** B - Web Application / Web Application Based Information System; C - Problem Solving and Artificial Intelligence; E - Smartphone Application; H - Image Processing

## Abstract

MediQore is an offline-capable digital health platform purpose-built for Pakistan's Lady Health Worker (LHW) programme. Paper-based record-keeping remains the norm across Pakistan's rural LHW network, creating critical gaps in maternal risk detection, immunisation tracking, polio campaign management, and nutrition surveillance. Existing digital tools; including LHW-MIS, DHIS2, and eVac; either require constant internet connectivity, support only the English language, or address only a narrow slice of LHW responsibilities, leaving most field operations unsupported. MediQore fills this gap through two integrated components: an Android mobile application serving LHWs in the field, and a web-based portal serving supervisors and administrators. The mobile application operates fully offline using an encrypted SQLite database, synchronising automatically with the central server whenever connectivity becomes available. An embedded maternal risk engine; trained on the UCI Maternal Health Risk Dataset (Ahmed et al., 2020) using Logistic Regression, Random Forest, and Gradient Boosting models with SMOTE-based class balancing; classifies each pregnancy as low, moderate, or high risk after every home visit, and presents the rationale in plain Urdu through a SHAP-derived static explanation lookup. Beyond maternal health, the platform covers house-to-house polio campaign recording, EPI child immunisation scheduling, WHO MUAC-based malnutrition screening, IMCI illness assessment, and ANC pregnancy journey tracking within a single Urdu-language application. The supervisor web dashboard delivers real-time field visibility, automated PDF and Excel report generation, and area-level analytics without requiring supervisors to wait for weekly paper submissions. MediQore represents the unified, offline-capable, Urdu-language platform to address the complete scope of LHW responsibilities within a single application, with the potential to materially strengthen maternal and child healthcare delivery across rural Pakistan.

## Introduction

Pakistan's Lady Health Worker programme places approximately 100,000 community health workers at the frontline of maternal and child healthcare delivery across the country's rural and peri-urban areas (National Health Services, Regulations and Coordination [NHSRC], 2023). Each LHW is responsible for a range of duties spanning pregnant woman monitoring, child immunisation, polio campaign participation, and malnutrition surveillance; all carried out across households that are often remote, poorly connected, and served by minimal health infrastructure. Despite the scale and importance of this programme, the tools provided to LHWs have not evolved beyond handwritten paper registers and manual reporting. This creates compounding problems: records are lost or damaged in field conditions, data cannot be analysed for risk patterns, supervisors cannot monitor activities in real time, and high-risk cases are identified too late for effective intervention. This document presents the scope, objectives, modules, and technical architecture of MediQore; a platform designed from the ground up to function under the actual constraints of Pakistan's LHW field environment. The system addresses connectivity limitations through a fully offline-capable mobile application built on Flutter with local SQLite storage and automatic background synchronisation. It addresses language barriers through a complete Urdu interface using the Jameel Noori Nastaleeq font and voice-guided data entry. It addresses decision-support gaps through an embedded AI maternal risk engine that classifies patients and explains results in Urdu after every visit. And it addresses scope fragmentation by covering every major LHW responsibility; maternal health, polio campaigns, child immunisation, nutrition screening, and pregnancy journey tracking within a single application, eliminating the need for multiple disconnected tools. The web-based supervisor portal complements the mobile application by providing real-time visibility into field activities, automated reporting, and area-level health analytics. Together, these components form a complete digital health ecosystem aimed at transforming paper-dependent LHW operations into a data-driven, AI-supported public health workflow.

## Problem Statement

Maternal and child health indicators in Pakistan remain among the most concerning in South Asia. According to the Pakistan Demographic and Health Survey 2017–18 (NIPS & ICF, 2019), the country's maternal mortality ratio stands at 186 deaths per 100,000 live births in rural areas, with hypertensive disorders alone responsible for 15 percent of those deaths and anaemia affecting 52 percent of pregnant women. Child malnutrition is similarly severe: UNICEF's 2020 Pakistan country brief estimates that over 40 percent of children under five experience stunting, placing Pakistan among the most affected countries in the Asia-Pacific region (UNICEF, 2020). Lady Health Workers are the primary point of contact for maternal and child health services across the communities where these burdens are highest, yet the tools available to them consist entirely of handwritten paper registers.

Every LHW documents patient data: blood pressure readings, weight, vaccination history, ANC visit dates, by hand in physical notebooks. These records are routinely lost during field visits, filled in incorrectly under time pressure, or left incomplete when LHWs attend multiple households in a single day. There is no mechanism to detect patterns in this data or flag a patient whose condition is deteriorating across multiple visits. When a high-risk pregnancy is identified, no formal digital channel exists for the LHW to generate a referral, notify her supervisor, or confirm whether the patient reached a hospital. The entire referral pathway from identification to outcome is invisible and untracked.

Polio eradication presents a parallel challenge. The WHO Global Polio Eradication Initiative (GPEI, 2024) reports that Pakistan remains one of the last countries globally where wild poliovirus transmission has not been interrupted, making campaign coverage tracking a national public health priority. Yet vaccination refusals and missed households are still recorded on paper during campaigns and rarely followed up systematically. The child immunisation programme faces similar shortfalls: children who miss scheduled doses are not consistently tracked, and coverage gaps in specific sub-areas remain invisible to supervisors until the next paper report cycle. Malnutrition screening for children is conducted visually or with a measuring tape, with no standardised digital record or automatic comparison against WHO thresholds.

Supervisors have no real-time visibility into field activities. They receive weekly or monthly paper compilations that arrive days after the events they describe. Disease outbreaks, emerging malnutrition clusters, and high-risk pregnancies are therefore identified after the optimal window for intervention has already closed. Existing digital platforms do not resolve this. LHW-MIS has no mobile interface and is used by supervisors only. DHIS2 requires constant internet connectivity and operates in English. No existing tool covers the full breadth of LHW responsibilities in a single application. MediQore is built to address all these gaps within a single offline-capable, Urdu-language platform designed specifically for the conditions in which LHWs actually work.

## Problem Solution / Objectives of the Proposed System

The proposed system is a complete digital health platform for Lady Health Workers, designed to replace paper-based processes with the help of AI and an intelligent, offline-capable mobile application and a web-based supervisor dashboard. The LHW mobile application provides a full Urdu interface with simple form-based data entry, making it usable by field workers without requiring advanced technical skills or English literacy. The system digitises patient registration, home-visit data collection, and follow-up tracking for pregnant women, eliminating dependency on paper registers that are easily lost or damaged. An AI-based risk scoring engine is embedded directly in the application and runs after every visit, automatically classifying pregnant women as Green, Yellow, or Red risk based on their health data, and explaining in plain Urdu why a patient has been flagged. For high-risk patients, the system generates referral recommendations, alerts supervisors instantly, and tracks whether the referral was completed, closing the loop that currently has no visibility. The platform also covers LHW responsibilities beyond maternal health: polio campaign tracking with house-by-house recording, child immunisation schedule management with defaulter alerts, and child nutrition screening using WHO-validated MUAC measurements and IMCI-based illness assessment for children. All data collected in the field is stored locally on the device when there is no internet and syncs automatically to the central server when connectivity is restored. The supervisor web dashboard gives area-level health analytics, LHW performance monitoring, and real-time risk visibility without requiring supervisors to wait for paper reports. Automated weekly and monthly reports are generated by the system in PDF and Excel format, ready for submission to health departments or donor organisations. The result is a platform that is more capable than any existing tool in Pakistan's LHW ecosystem, covering every major LHW responsibility in one application with AI decision support, offline functionality, and full Urdu localisation.

### 3.1 Objectives

- BO-1: Digitise LHW patient records and replace paper registers with an offline-capable Urdu mobile application that covers all major LHW responsibilities in a single platform.
- BO-2: Implement an AI-based maternal risk classification engine trained on the UCI Maternal Health Risk Dataset with SMOTE-based class balancing, comparing Logistic Regression, Random Forest, and Gradient Boosting models evaluated via five-fold stratified cross-validation, reporting F1-macro and per-class F1 scores. The model is domain-validated against PDHS 2017-18 Pakistan population risk profile statistics confirming feature alignment with Pakistan’s observed maternal mortality risk profile. Classifier selection prioritizes recall on the high-risk class above overall accuracy, with a minimum acceptable high-risk recall threshold set at 90 percent, because a false negative for a high-risk patient represents a missed obstetric emergency with potentially fatal consequences.
- BO-3: Integrate a polio campaign management module that supports house-to-house vaccination tracking, refusal recording, and zero-dose child identification.
- BO-4: Cover child immunisation, child nutrition and growth screening, and IMCI-based illness assessment in the same platform so that LHWs do not need multiple separate tools.
- BO-5: Provide supervisors with a real-time web dashboard that gives field-level visibility, LHW performance metrics, and area-level health analytics.
- BO-6: Automate the generation of weekly and monthly health reports in PDF and Excel format, replacing manual report preparation by LHWs and supervisors.

## Related System Analysis / Literature Review

Several systems currently exist that partially address the needs of Pakistan's LHW network, but none provides a complete solution.

Table 1: Related System Analysis with Proposed Project Solution

| Application Name | Weaknesses | Proposed Project Solution |
|---|---|---|
| LHW-MIS (Government) | PC-based, no mobile interface. English only. No AI or risk scoring. Not usable by LHWs in the field. | Full Urdu mobile app. Offline-capable. AI risk scoring built-in. Designed specifically for LHW field use. |
| DHIS2 | Technically complex UI. English only. No AI or predictive features. Requires constant internet. | Simple form-based interface. Offline sync. AI decision support. Urdu labels and voice guidance. |
| eVac (EPI System) | Only handles vaccination. No maternal health. No polio campaign management. No nutrition or disease modules. | Covers all LHW responsibilities. Full EPI module integrated. Combined with maternal, polio, nutrition, and disease modules. |
| NGO Pilot Apps | Siloed, single-function tools. Not designed for national scale. No standard reporting. No AI support. | Complete multi-role platform. Scalable to any district. Automated standardised reports. AI engine embedded. |
| CommCare (Dimagi) | Generic platform requiring major customisation for Pakistan’s LHW workflows. No on-device AI risk scoring, Urdu voice guidance, or automated Urdu explanations. Limited offline practicality. | Purpose-built for Pakistan’s LHW workflow with embedded offline risk scoring, static Urdu explanations, full Urdu interface, voice guidance, and automatic sync. |
| OpenSRP (Ona / IIPH) | Complex FHIR-based setup with no Urdu support, voice guidance, or embedded offline AI risk classification. Not designed specifically for Pakistan’s LHW or polio workflows. | Designed specifically for Pakistan’s LHW structure with built-in offline risk assessment, Urdu voice guidance, and deployment without complex reconfiguration. |

## Vision Statement

For Lady Health Workers in Pakistan who manage maternal health, polio campaigns, child immunisation, and nutrition screening across rural communities without any digital support, MediQore is a complete mobile and web-based digital health platform that uses artificial intelligence to identify high-risk patients, track the full pregnancy journey, manage polio campaigns, monitor child health, and generate automated health reports. Unlike the outdated government LHW-MIS, the English-only DHIS2 system, and the single-function eVac tool, MediQore is the AI-assisted, offline-capable, Urdu-language application that covers every major LHW responsibility in a single solution, giving LHWs the tools they need to work effectively, giving supervisors the visibility they need to manage their areas, and giving health departments the real-time data they need to make decisions that save lives.

## Scope

The proposed system is a complete digital health platform for Lady Health Workers in Pakistan, consisting of two main components: a mobile application for LHWs and a web-based dashboard for supervisors and administrators. The mobile application is built on an offline architecture with a full Urdu interface, allowing LHWs to register pregnant women, collect home-visit data, receive AI-generated risk alerts, manage polio campaigns, track child immunisation, screen for malnutrition and illness, all from their Android smartphones without requiring internet connectivity in the field. The system covers ten functional modules, each addressing a distinct aspect of LHW responsibilities. The AI risk engine runs embedded in the application after every patient visit, classifying maternal risk as Green, Yellow, or Red based on health indicators, and providing plain-language Urdu explanations of each risk result. Emergency referrals for high-risk patients are generated automatically. Critical conditions are additionally detected by a rule-based danger-sign safeguard that runs independently of the AI model, and emergency alerts are escalated to the supervisor through three layers (internet notification, SMS, and voice call). All three alert options are available to the LHW at all times on the emergency screen, so she can escalate through whichever channel is available to her at that moment, and an on-screen emergency protocol ensures that critical cases are handled safely even when the device is offline. The offline sync engine stores all field data locally on the device when there is no internet and uploads it to the central server automatically when connectivity is restored. The supervisor web dashboard provides real-time visibility into LHW field activities, area-level health analytics, risk distribution, LHW performance monitoring, and referral completion tracking. Polio campaign operations are covered through a dedicated module that supports house-to-house vaccination recording, refusal tracking, and zero-dose child identification. Child immunisation is tracked against the full Expanded Programme on Immunisation (EPI) schedule with automated defaulter alerts. Child nutrition is screened using WHO-validated MUAC measurements with automatic SAM and MAM classification. The Pregnancy Journey and Health Records module combines longitudinal ANC monitoring, TT vaccination scheduling, supplement compliance tracking, and a permanent digital patient health record with automated trend analysis. The system generates automated PDF and Excel reports at weekly and monthly intervals, ready for submission to health departments, NGOs, and donor organisations. An admin panel manages user accounts, district and area structures, hospital records, and system access, with a complete audit log recording all system activity for transparency and accountability. Voice guidance is built into the data entry screens, with the application reading field labels aloud in Urdu to assist LHWs with lower reading ability, improving both data quality and user confidence in the field.

## Modules

The system is divided into ten functional modules. Modules 1 through 9 are delivered through the LHW Android mobile application. Module 10 is a web-based portal for supervisors and system administrators. All mobile modules operate with full offline capability.

### 7.1 Module 1: LHW Onboarding & Access Control

This module handles the creation and management of LHW accounts, login, and role-based access. It is the entry point of the system for all users and ensures that only authorised personnel can access patient data.

- FE-1: LHW account creation by admin with assigned district, Union Council, and area: each LHW receives a unique ID, login credentials, and an area-specific patient list automatically generated at the time of account creation.
- FE-2: Secure role-based authentication for LHWs, supervisors, and admin users using JWT-based login, OTP verification, HTTPS-secured communication, server-side API validation, and automatic session expiry to protect patient data and prevent unauthorized access, even if a device is lost.
- FE-3: LHW profile management including area reassignment, account activation or deactivation, and password reset: all controlled from the admin panel by authorised administrators only.
- FE-4: Interface language selection *(A1)*: the LHW mobile application can be used in Urdu, the default, or in English. The LHW chooses the language on the login screen or in the app settings; the choice is kept on the device and applies to every screen at once, with Urdu laid out right to left and English left to right. Voice guidance (Module 3 FE-3) is available only in Urdu and is switched off while English is selected.

### 7.2 Module 2: Expecting Woman Registration

This module handles the registration of new pregnant patients into the system. Each registration creates a permanent digital health file that is linked to the LHW and remains accessible throughout the pregnancy. It is intentionally distinct from visit data collection, which is handled in a separate module.

- FE-1: New patient registration form capturing name, age, husband's name, contact number, address, pregnancy month, and village: with automatic generation of a unique Patient ID and a digital pregnancy file that persists for the full duration of the pregnancy.
- FE-2: Capture of complete obstetric history including number of previous pregnancies, previous C-sections, stillbirths, and known medical conditions at the time of registration, forming the baseline risk profile used by the AI engine.
- FE-3: Household mapping with GPS tagging of the patient's home location, enabling area-based search, visit routing, and geographic risk reporting on the supervisor dashboard.

### 7.3 Module 3: Field Visit & Vitals Collection

This module is used during every home visit to collect the patient's current health data. It is a standalone data entry module separate from registration and separate from risk scoring, which runs automatically after this form is submitted.

- FE-1: Structured Urdu data-entry form for recording blood pressure, weight, temperature, fetal movement, swelling, bleeding, fever, anaemia signs, and urine symptoms using checkboxes, dropdowns, and large touch-friendly controls. The interface uses the bundled Jameel Noori Nastaleeq font with Flutter RTL Directionality support to ensure proper Urdu rendering and layout on Android devices.
- FE-2: An Offline, encrypted storage and synchronized data upload: Visit records are stored locally using encrypted SQLite (Drift + sqflite_sqlcipher) with AES-256 protection. Each record receives a client-generated UUID for offline operation. When connectivity is restored, records automatically sync to the central server, which assigns server-side sequence IDs and performs conflict detection for duplicate offline submissions. Conflicted records are flagged for supervisor review and preserved in the audit log instead of being overwritten.
- FE-3: Voice-guided assistance during data entry that reads field labels aloud in Urdu, for example, when the blood pressure field is opened, the application announces the corresponding Urdu instruction: helping LHWs with lower reading ability to fill in forms accurately and independently. *(A1)* Voice guidance runs only while the application is in Urdu; it is switched off when the LHW selects English (Module 1 FE-4).

### 7.4 Module 4: AI-Based Maternal Risk Assessment

This module runs automatically after every visit form is submitted. It is the core AI component of the system and operates entirely separate from the data collection module. It processes the submitted visit data and patient history to generate a risk classification and recommendation.

- FE-1: Multi-model risk scoring with on-device inference: Logistic Regression, Random Forest, and Gradient Boosting models are trained on the UCI Maternal Health Risk Dataset using features including SystolicBP, DiastolicBP, BloodSugar, BodyTemp, HeartRate, and Age for low-, mid-, and high-risk classification. SMOTE-based class balancing and validation against PDHS 2017–18 maternal health statistics are applied during training. Model evaluation uses stratified cross-validation with F1-score, per-class recall, and ROC-AUC metrics, prioritizing high-risk patient recall to reduce missed obstetric emergencies. The best-performing model is exported to ONNX using sklearn2onnx and deployed for fully offline on-device inference in Flutter through ONNX Runtime Mobile, with benchmark validation for prediction consistency and low-latency execution on low-spec Android devices.
- FE-2: SHAP-derived static Urdu explanation: During training, SHAP analysis identifies the top contributing feature-threshold combinations per risk class. These mappings are exported as a JSON lookup table bundled inside the Flutter app as a static asset. At inference time, the app reads the model's predicted class and the input feature values, queries the lookup table, and displays the matched Urdu clinical phrase as the explanation. SHAP itself runs only during training in Python and has no runtime dependency on the device.
- FE-3: Risk trend tracking across multiple visits; the system monitors whether a patient's risk level is increasing, stable, or improving over time, and alerts the LHW when a gradual deterioration pattern is detected even if a single visit reading appears borderline.
- FE-4: Critical-condition detection (rule-based safety override): In addition to the ML classification, every submitted visit is checked on the device against a fixed set of WHO-aligned obstetric danger-sign rules that are evaluated independently of the model, so that a critical case is never missed because of a model error. A visit is classified as an Emergency (automatically Red-risk) if any of the following is recorded: severe hypertension (systolic BP of 160 mmHg or above, or diastolic BP of 110 mmHg or above); vaginal bleeding; absent or markedly reduced fetal movement; high fever (38 °C or above) together with another danger sign; swelling combined with raised blood pressure; or severe anaemia signs. The final risk level is always the higher of the ML result and the rule-based result. The rules run fully offline inside the Flutter app the moment the visit form is submitted, and the thresholds are stored in a configuration file so that they can be reviewed by clinical advisors before deployment. An Emergency result immediately triggers the emergency-handling workflow described in Module 5.

### 7.5 Module 5: Emergency Referral Coordination

This module activates when a patient is flagged as Red-risk or as an Emergency by the danger-sign rules of Module 4. It manages the entire referral process from generation to outcome recording. It is fully separate from the risk engine: the risk engine flags the patient, and this module manages what happens next. It also defines how critical cases are escalated and safeguarded when internet connectivity is weak or unavailable.

- FE-1: One-tap referral generation for Red-risk patients: the system automatically fills the referral form with patient details, risk factors, and the name and location of the nearest available referral hospital or District Headquarters Hospital (DHQ).
- FE-2: Three-option emergency alert to the supervisor: the moment a Red-risk or Emergency patient is flagged, the emergency screen presents all three alert options together as equal, one-tap buttons, so the LHW can use whichever is easiest and available to her at that moment. The options are independent: none of them depends on another, and none is a prerequisite for the others. Layer 1 (Internet): an instant in-app push notification and a real-time alert on the supervisor web dashboard, delivered through the backend when mobile data or Wi-Fi is available. Layer 2 (SMS): a pre-filled emergency SMS containing the patient ID, LHW name, area, key risk factors, and a GPS location link (where available), sent over the cellular network directly from the LHW's own device; this option needs no internet connection and no paid gateway subscription. Layer 3 (Voice call): a one-tap direct call from the emergency screen to the supervisor's registered number, with a secondary contact (for example the district programme coordinator or the nearest referral hospital) available as a fallback, for cases that need immediate verbal escalation. The LHW may use one, two, or all three options, and a single “Send all” button triggers every option that is currently available. The screen shows which options are currently usable (for example, the internet option is marked as unavailable when there is no data connection) so that she can choose without delay. Every attempt is recorded in the audit log with its timestamp, channel, and delivery status. See LI-4 and LI-11 for the limitations of these options.
- FE-3: After the referral is created, the LHW records whether the patient attended the hospital and what the outcome was, closing the referral loop and making the complete result visible to the supervisor on the dashboard.
- FE-4: Offline critical-case handling and safeguards: escalation of a critical case never has to wait for internet. The danger-sign rules and the risk model both run on the device, so detection works fully offline. When an Emergency or Red-risk patient is flagged, (a) a persistent, non-dismissible emergency screen appears with an Urdu voice announcement and a step-by-step emergency protocol checklist (stay with the patient, treat according to the danger sign, arrange transport, and contact the supervisor or hospital); (b) all three alert options are available immediately on that screen, and when there is no internet, Layer 2 (SMS) and Layer 3 (call) work over the cellular network so the LHW is never blocked; (c) the emergency alert record is saved locally with its timestamp and is synchronised to the server whenever internet becomes available, so that the dashboard and audit log are completed; this synchronisation is for record-keeping and supervisor visibility only and is not required for escalation through SMS or call; (d) the screen shows the status of each option (Sent, Failed, or Not available) with a retry button, and keeps an “Alert not yet delivered” warning visible until at least one option is confirmed; (e) every alert carries the original visit timestamp and the recorded time-to-escalation, so supervisors can see any delay; and (f) only where neither internet nor cellular coverage is available, so that none of the three options can be used, the screen instructs the LHW to proceed with physical referral without waiting for acknowledgement and to reach the nearest point of coverage to send the alert.
- FE-5: Alert acknowledgement and automatic escalation: the supervisor acknowledges each emergency alert from the dashboard or the app. When the LHW reaches the supervisor by call, or receives a reply by SMS, she can also mark the alert as “supervisor reached” on her device, which counts as an acknowledgement. The acknowledgement status is shown on both the LHW's device and the dashboard. If an alert is not acknowledged within a configurable time (default 15 minutes), the system re-sends it and escalates to the secondary contact configured by the administrator. Unacknowledged emergency alerts are highlighted on the supervisor dashboard and listed in the periodic reports.

### 7.6 Module 6: Pregnancy Journey, Health Records & ANC Monitoring

This module combines longitudinal pregnancy timeline management with a permanent digital health record vault for every patient. It manages the full ANC visit schedule, vaccination and supplement compliance, uploaded health reports, and automated trend analysis across all recorded visits. It is architecturally distinct from the visit data collection module: Module 3 records today's measurements, while this module tracks what those measurements mean over the full course of the pregnancy and stores all associated documentation.

- FE-1: ANC visit schedule tracking: The system generates a personalised visit schedule based on the patient's gestational age at registration, sends automated reminders for upcoming visits, and flags any visit that has been missed beyond its scheduled date. TT vaccination dose scheduling and iron tablet and folic acid compliance tracking are integrated into the same timeline, with a supplement compliance score calculated over the pregnancy and visible on the patient profile.
- FE-2: OCR-assisted health record capture with LHW verification: LHWs can scan hospital reports using the device camera, where Google ML Kit performs fully offline OCR text extraction. A regex-based medical entity extraction engine identifies clinical values such as blood pressure, haemoglobin, blood glucose, temperature, weight, and urine protein status. High-confidence values are auto-filled for LHW verification, while uncertain fields require manual confirmation. Verified records are stored for future trend analysis and risk assessment, while original report images are preserved as reference documents. If OCR fails on handwritten or unclear reports, the workflow automatically falls back to manual data entry.
- FE-3: Automated trend analysis and automated progress report generation: After multiple visit records are available, the system performs longitudinal trend analysis using linear regression and Z-score anomaly detection to identify deteriorating health patterns and abnormal vital changes. ANC attendance, iron supplement usage, and folic acid adherence are combined into a weighted treatment compliance score. The system then generates a bilingual PDF progress report containing vital trend graphs, visit history, ANC compliance status, doctor notes timeline, and automated Urdu health summaries for hospital follow-up and continuity of care.

### 7.7 Module 7: Polio Campaign Field Operations

This module supports the house-to-house polio vaccination campaigns that LHWs conduct in their assigned areas. It is an entirely separate module from the EPI child immunisation module: polio campaigns are mass campaigns conducted on specific dates, while EPI covers routine scheduled vaccination tracking for individual children.

- FE-1: House-to-house polio campaign recording: for each household in the LHW's assigned area, she records the number of children under 5, the number vaccinated, the vaccine type (OPV), and the campaign date; with full offline saving for areas with no connectivity during field operations.
- FE-2: Refusal tracking: households that refuse vaccination are recorded separately with the stated reason for refusal (religious concern, misinformation, past reaction, absent family), and a re-visit is automatically scheduled for follow-up during the same campaign round.
- FE-3: Zero-dose child identification: the system cross-references polio campaign records with the child registration database and flags any child under 5 who has never received any OPV dose in any campaign round, generating a priority follow-up list for the LHW and supervisor to ensure complete coverage within the catchment area.

### 7.8 Module 8: Child Immunization & EPI Management

This module tracks the routine EPI vaccination schedule for each registered child. It is completely separate from the polio campaign module: EPI covers all scheduled vaccines given at specific age milestones, not campaign-based oral polio doses. The two modules share the child registration database but manage distinct vaccination records.

- FE-1: Full EPI schedule tracking for each registered child under 2 years: the system generates a personalised vaccination timeline based on the child's date of birth and tracks completion of all EPI doses (BCG, OPV-0, Penta 1/2/3, PCV 1/2/3, Rota 1/2, IPV, MR) against their due dates, clearly distinguishing birth-dose OPV-0 from campaign OPV doses tracked in Module 7.
- FE-2: Defaulter alert generation: when a child misses a scheduled vaccine dose beyond its due date, an automated alert appears on the LHW's dashboard and the supervisor is notified, triggering a follow-up visit to complete the missed dose before the child falls further behind schedule.
- FE-3: Area immunisation coverage reporting: the system calculates the percentage of fully vaccinated children in the LHW's assigned area for each antigen and displays a coverage summary on the supervisor dashboard, identifying specific vaccines and specific sub-areas with low coverage for targeted intervention.

### 7.9 Module 9: Child Nutrition & Growth Screening

This module handles malnutrition screening, growth monitoring, and IMCI-based childhood illness assessment for children under 5. It uses the WHO Mid-Upper Arm Circumference (MUAC) standard and WHO Z-score growth charts for nutrition classification, and WHO IMCI validated decision logic for illness severity assessment. All classification in this module is rule-based using WHO-validated thresholds and algorithms.

- FE-1: MUAC measurement entry with automatic WHO classification: the entered MUAC value in millimetres is instantly classified against WHO-defined thresholds (WHO, 2013); values below 115 mm indicate Severe Acute Malnutrition (SAM), values between 115 mm and 125 mm indicate Moderate Acute Malnutrition (MAM), and values above 125 mm are classified as Normal; with a colour-coded result displayed in Urdu. Weight-for-age and height-for-age Z-score calculation is also provided, identifying stunting, wasting, or underweight status against WHO Child Growth Standards (WHO, 2006).
- FE-2: SAM referral generation and follow-up tracking: children classified as SAM are automatically referred to the nearest Nutrition Rehabilitation Centre, and the system tracks whether the child attended and monitors weight recovery progress across follow-up visits, ensuring no SAM child is lost to follow-up.
- FE-3: IMCI-based diarrhea and pneumonia severity assessment: using WHO Integrated Management of Childhood Illness (IMCI) decision logic, the system guides the LHW through a structured symptom checklist (respiratory rate, chest indrawing, stool frequency, dehydration signs) and generates a severity classification with the recommended action in Urdu, enabling the LHW to triage sick children without requiring clinical training.

### 7.10 Module 10: Supervisor Dashboard, Reporting & Administration

This web-based module serves supervisors and system administrators. It combines real-time field visibility, automated formal report generation, and complete backend system management in one web portal, keeping all administrative and oversight functions on the web side, separate from the field-facing mobile modules.

- FE-1: Real-time supervisor dashboard showing total registered patients, risk distribution (Green / Yellow / Red), referral completion rates, LHW activity monitoring (visit rates, missed visits, overdue follow-ups, last login), and area-level health analytics with an auto-refreshing geographic risk map (implemented using Leaflet.js with GPS coordinate data from Module 2) showing high-risk pregnancy clusters, malnutrition hotspots, and immunisation coverage gaps; the map refreshes automatically every five minutes or on manual reload by the supervisor, and is filterable by district, Union Council, LHW, and time period.
- FE-2: Automated weekly and monthly report generation in PDF and Excel format: covering maternal health summaries, high-risk case lists, referral completion rates, LHW activity logs, polio campaign progress, immunisation coverage, and child nutrition screening results; ready for submission to health departments, NGOs, or donor organisations without any manual preparation.
- FE-3: Admin panel and audit log: admins manage district, tehsil, Union Council, and area structures; LHW and supervisor accounts; hospital and referral centre records; emergency escalation contacts (supervisor and secondary contact numbers per area); and role permissions. A full audit log records every data entry, edit, deletion, referral, and login event with timestamp and user identity, ensuring complete system transparency and accountability.
- FE-4: LHW inactivity anomaly detection: the supervisor dashboard continuously monitors each LHW’s weekly visit count against her personal historical baseline. If a given week’s visit count falls more than two standard deviations below that LHW’s own mean, the dashboard automatically raises an unusual inactivity flag with a prompt to verify field activity. This statistical anomaly detection requires no external library; it uses only the mean and standard deviation of each LHW’s recorded visit history, making it computationally lightweight while adding genuine intelligence to the supervisor oversight layer.

## System Limitations / Constraints

- LI-1: The system requires Android smartphones for the LHW mobile application. iOS is not supported in the current version due to development cost constraints. This is not a practical limitation since the vast majority of LHWs in Pakistan use Android devices.
- LI-2: The UCI Maternal Health Risk Dataset was selected as the primary training source following a feature alignment review against the Pakistan Demographic and Health Survey 2017-18. The PDHS 2017-18 reports that hypertensive disorders account for 15% of maternal deaths in Pakistan, and anaemia prevalence among pregnant women stands at 52%. The UCI dataset includes blood pressure and haemoglobin-related features as primary predictors, confirming that the model’s input features are clinically consistent with Pakistan’s observed maternal mortality risk profile. Individual-record Pakistani maternal health data is not publicly available; this project identifies the absence of a publicly accessible, individual-record Pakistani maternal health dataset suitable for machine learning model training as a critical gap in Pakistan’s health data infrastructure. A key outcome of MediQore’s deployment phase will be the collection of the first LHW-sourced, field-validated maternal health dataset from rural Pakistan, which will be used to fine-tune and re-validate the model in future work.
- LI-3: Visual anaemia detection via conjunctiva photography and referral no-show prediction are not included in the current version, as both require training datasets that do not yet exist. Both are designated as future enhancements following production deployment.
- LI-4: Layer 1 emergency alerts (in-app push and dashboard) require an internet connection. Layer 2 (SMS) and Layer 3 (voice call) require cellular network coverage and available SIM balance on the LHW's device. The prototype sends SMS and places calls directly from the LHW's device, so no paid gateway subscription is needed. Server-side SMS gateway delivery (for example automated bulk or backend-initiated SMS) is planned for production deployment and is not part of the prototype.
- LI-5: All AI outputs are decision-support recommendations only. The system does not replace clinical diagnosis by a qualified health professional, and this limitation is clearly stated in the application interface and system documentation.
- LI-6: The voice guidance feature reads field labels in Urdu only. LHWs operating in areas where Urdu is not the primary spoken language will benefit from the visual Urdu interface but may receive less benefit from the audio guidance. *(A1)* When the LHW switches the application to English (Module 1 FE-4), voice guidance is switched off, because the spoken labels exist in Urdu only.
- LI-7: Offline sync conflict resolution uses server-assigned sequence numbers rather than device timestamps, as low-cost Android handsets may have unsynchronised clocks. Conflicts currently require manual supervisor review; automated per-field merge resolution is planned for production.
- LI-8: The local SQLite database on LHW devices is encrypted using AES-256 via sqflite_sqlcipher. The encryption key is derived from the LHW’s login credentials. If an LHW forgets their password and the admin resets it, the locally stored offline data on that device will become inaccessible until the device re-syncs after the new login. LHWs are instructed to sync before requesting resets. A key recovery mechanism using an admin-held device-specific recovery key is planned for the production deployment phase.
- LI-9: OCR record scanning performs best on printed, structured hospital reports. Handwritten notes faded thermal receipts, and low-light photographs may reduce extraction accuracy and require manual entry. LHW confirmation is mandatory for every scanned record regardless of confidence level.
- LI-10: No real patient data will be collected or processed until IEC approval is obtained from COMSATS University Islamabad's Institutional Ethical Committee, to be submitted in Semester 7. The prototype will be developed and demonstrated entirely on synthetic dummy data.
- LI-11: The three alert options use different channels (internet, cellular SMS, and cellular voice), so an emergency can still be escalated without internet as long as cellular coverage exists. Only where a patient is in an area with neither internet nor cellular coverage can none of the three options be used. In that case the system still detects the critical condition on the device, shows the emergency protocol, and saves the alert record, which is synchronised as soon as any connectivity returns; the delivery time of an alert in such an area therefore depends on network coverage and cannot be guaranteed. The application clearly shows the “Alert not yet delivered” status, and the LHW must follow the on-screen protocol and arrange physical referral without waiting for supervisor acknowledgement.
- LI-12: The danger-sign thresholds used for critical-condition detection are WHO-aligned standard values and have not been validated on Pakistani field data. They are set conservatively to favour sensitivity, so false alarms are possible. Detection also depends on the LHW entering vitals and symptoms correctly, and incorrect entries cannot be identified by the system. The thresholds are to be reviewed by clinical advisors before any real-world deployment.

## Data Gathering Approach

Requirements for the proposed system were gathered through literature review, existing system analysis, clinical protocol review, and structured consultations with Lady Health Workers (LHWs) and supervisors. Research reports from UNICEF, USAID, PDHS 2017-18, WHO ANC guidelines, WHO IMCI protocols, and Pakistan’s EPI schedule were reviewed to define system workflows, clinical logic, and maternal risk model features. Existing platforms including LHW-MIS, DHIS2, CommCare, OpenSRP, and eVac were analysed to identify their limitations and determine the competitive positioning of the proposed system. Informal workflow discussions with LHWs and supervisors were conducted to understand field challenges, critical paper-register data, reporting difficulties, and usability requirements for the Urdu interface. Feedback from these consultations influenced the final design of Modules 2 and 3, including simplified checkbox-based symptom entry and field ordering aligned with existing LHW workflows.

## Project Contribution

MediQore makes the following original technical and conceptual contributions to Pakistan's healthcare technology landscape:

- First Integrated Multi-Role LHW Platform: No existing system in Pakistan covers all major LHW responsibilities: maternal health, polio campaigns, child immunisation, nutrition screening, and IMCI-based illness assessment; in a single application. MediQore is the first to do so in a single offline-capable Urdu platform.
- AI-Assisted Maternal Risk Classification with Pakistan Context: The maternal risk engine is trained on the UCI Maternal Health Risk Dataset and domain-validated against PDHS 2017-18 Pakistan population risk profile statistics, confirming that the selected risk indicators are consistent with observed maternal health patterns across Pakistan. This makes it the most Pakistan-contextual AI model applied to LHW workflows in academic research.
- Offline Architecture for Rural Pakistan: Unlike DHIS2 and LHW-MIS, this system is designed from the ground up to work without internet. All field data is stored locally using SQLite (Drift) and synchronised automatically, making it practical for Pakistan's rural areas where connectivity is unreliable.
- Full Urdu Interface with Voice Guidance: This is the first LHW health application to offer a complete Urdu interface with voice-guided data entry, directly addressing the language and literacy barriers that make every existing system unusable by field workers in the field.
- Automated Natural Language Report Generation: The system generates natural language health reports in PDF and Excel format automatically, eliminating the manual report-writing burden that currently consumes significant LHW and supervisor time every week.
- Referral Loop Closure: Unlike any existing system, this platform tracks not just whether a referral was made, but whether the patient attended the hospital and what the outcome was; closing a critical gap in Pakistan's maternal health referral pathway.
- Zero-Dose Child Identification for Polio Eradication: By cross-referencing polio campaign records with child registration data, the system automatically identifies children who have never received any OPV dose; directly supporting Pakistan's polio eradication effort in a way that no current LHW tool does.
- Longitudinal Patient Health Record with Automated Health Trend Analysis: The merger of the pregnancy journey, ANC schedule, supplement compliance, health record storage, and automated trend analysis into a single longitudinal patient file gives each pregnant woman a complete health history accessible at any point, a capability unavailable in any current LHW system.
- On-Device Computer Vision Pipeline for Medical Document Digitisation: MediQore integrates a hybrid on-device OCR pipeline using Google ML Kit's LSTM-based text recognition model combined with a custom medical entity extraction engine. This enables LHWs to digitise patient hospital reports through a single photograph taken on a low-cost Android device, with no internet connection required. The pipeline operates with a graceful degradation model: successful extractions are pre-filled and verified by the LHW, while failed extractions fall back to manual entry, ensuring the workflow is never blocked by OCR failure. This is the first integration of on-device medical document OCR into a community health worker application designed for rural Pakistan field conditions.
- Future Enhancement: Referral No-Show Prediction: A logistic regression model trained on longitudinal referral outcome data will predict which referred patients are at elevated risk of missing their hospital appointment, enabling supervisors to prioritise follow-up before the appointment-window closes. This feature is planned for implementation after production deployment and generates sufficient training data.
By combining AI, offline architecture, Urdu localisation, voice guidance, and comprehensive multi-role coverage, MediQore transforms the LHW from an isolated paper-based field worker into a digitally empowered community health agent, with a direct positive impact on maternal and child health outcomes in rural Pakistan.

## Relevance to Course Modules

- Software Engineering: Requirements gathering, scope documentation, SDLC phases, use case modelling, and system design; all applied directly to this project across both semesters.
- Artificial Intelligence / Machine Learning: Logistic Regression, Random Forest, Gradient Boosting used for maternal risk classification, and rule-based WHO algorithms applied to malnutrition and child health modules.
- Database Systems: Structured patient data storage, relational data modelling for patient records, visit logs, referrals, immunisation history, and audit logs using PostgreSQL.
- Mobile Application Development: Android application developed using Flutter with offline storage, SQLite (Drift), form-based data entry, and Urdu localisation including TTS voice guidance, with an English interface the LHW can switch to *(A1)*. Interface design and large-button layout used by LHW through the mobile app.
- Web Technologies: React.js used for the supervisor web dashboard with real-time data visualisation, charts, heatmaps, and filterable analytics tables. REST API architecture connecting the mobile application to the backend server, with offline sync queuing managing data integrity across intermittent connections. Colour-coded risk results designed specifically for low-literacy users in a field environment with limited cognitive load.
- Computer Vision: On-device medical document recognition using Google ML Kit's LSTM-based OCR model. Concepts applied include image preprocessing (grayscale conversion, contrast enhancement), text detection and recognition pipelines, confidence scoring, and post-OCR information extraction using pattern matching. The feature enables LHWs to digitise patient hospital reports through a single photograph, with the extracted clinical values (blood pressure, haemoglobin, glucose, weight) automatically mapped to structured health record fields for trend analysis and AI risk scoring.

## Tools and Technologies

Table 2: Tools and Technologies for the Proposed Project

| Category | Tool / Technology | Version | Purpose |
|---|---|---|---|
| Mobile App | Flutter | 3.x | LHW Android application with Urdu UI (English selectable, A1), voice guidance, and offline support |
| Web Frontend | React.js | 18.x | Supervisor web dashboard with charts, heatmaps, and analytics |
| Backend API | Node.js + Express.js | 20.x | REST API server for mobile and web communication |
| Authentication | jsonwebtoken (Node.js) | Latest | JWT access and refresh token generation and verification for all API endpoints |
| Input Validation | Joi (Node.js) | Latest | Server-side API request body validation and sanitization before any database operation |
| Transport Security | TLS via HTTPS | N/A | All client-server communication encrypted in transit; plain HTTP rejected at server level |
| AI / ML | Python + scikit-learn | 3.11 / 1.4 | Maternal risk model training with SMOTE, cross-validation, and ONNX export via sklearn2onnx |
| Model Export | sklearn2onnx (Python) | Latest | Converts trained scikit-learn model to ONNX format for on-device inference via ONNX Runtime Mobile |
| On-device Inference | onnxruntime (Flutter) | Latest | On-device offline inference of the ONNX-exported scikit-learn model on the LHW Android device via ONNX Runtime Mobile |
| Database | PostgreSQL | 15.x | Central relational database for all patient and system data |
| Local Storage | SQLite (via Drift) | Latest | Offline data storage inside the Flutter mobile application |
| Local Storage Encryption | sqflite_sqlcipher (Flutter) | Latest | AES-256 encryption of the local SQLite database on the LHW Android device, protecting patient data at rest in case of device loss or theft |
| TTS (Voice) | flutter_tts | Latest | Voice-guided field label reading in Urdu for LHW data entry assistance |
| Localisation | flutter_localizations + intl (Flutter) | Latest | RTL locale configuration, Urdu language support, and bidirectional text rendering throughout the application; English (left-to-right) interface selectable by the LHW (A1) |
| Device Settings *(A1)* | shared_preferences (Flutter) | Latest | Keeps the chosen interface language on the phone, outside the encrypted database so the login screen can read it before sign-in; never holds patient data |
| Urdu Font | Jameel Noori Nastaleeq (bundled asset) | N/A | Urdu Nastaliq-script font bundled in Flutter assets for correct calligraphic rendering of all Urdu text labels, form fields, and risk explanations |
| Bidirectional Text | Flutter Directionality widget | N/A | Wraps all Urdu-language UI sections in RTL context, ensuring correct layout for Urdu labels alongside left-to-right numeric vitals values |
| Report Generation | pdfkit + ExcelJS | Latest | Automated PDF and Excel health report generation |
| IDE | VS Code | Latest | Primary development environment for all components |
| UI Design | Figma | Latest | Mobile app and web dashboard UI/UX wireframes and mockups |
| Version Control | Git + GitHub | Latest | Source code management and team collaboration |
| Data Source 1 | PDHS 2017-18 (DHS Program) | _ | Pakistan-specific maternal and child health data used for domain validation of AI model risk indicators against population-level statistics |
| Data Source 2 | UCI Maternal Health Risk Dataset | _ | Primary training dataset for maternal risk AI model |
| Class Imbalance Handling | imbalanced-learn (SMOTE) | Latest | Synthetic Minority Oversampling to address class imbalance in the UCI Maternal Health Risk Dataset before model training |
| Model Explainability | SHAP (Python) | Latest | Run during model training to identify feature-threshold-to-risk-class mappings. Output is exported as a JSON lookup table bundled inside the Flutter app for offline Urdu explanation generation at inference time |
| SHAP Explanation Asset | JSON lookup table (Flutter asset) | N/A | Pre-generated SHAP feature-threshold-to-Urdu-phrase mapping file bundled in app for offline inference-time explanation without any Python runtime dependency |
| Charting (Mobile) | fl_chart (Flutter) | Latest | Vital trend line graphs in the patient progress report and health record screen. |
| Statistical Analysis | numpy + scipy (Python, backend) | Latest | Linear regression for trend prediction and Z-score anomaly detection on patient vital history. |
| On-device OCR | google_mlkit_text_recognition (Flutter) | Latest | On-device LSTM-based text recognition for hospital report scanning; works fully offline |
| Image Capture | camera + image_picker (Flutter) | Latest | Camera access for report scanning and gallery selection |
| Image Preprocessing | image (Flutter) | Latest | Grayscale conversion and contrast enhancement before OCR to improve extraction accuracy |
| Medical Entity Extraction | Custom Dart regex engine | - | Pattern-based extraction of clinical values (BP, Hb, glucose, weight) from raw OCR text output |
| Emergency Alert (Layer 1) | Firebase Cloud Messaging + flutter_local_notifications | Latest | Push notification of emergency alerts to the supervisor when internet is available, and local on-device emergency notifications |
| Emergency Alert (Layers 2 & 3) | another_telephony + flutter_phone_direct_caller + permission_handler | Latest | Sending pre-filled emergency SMS over the cellular network and one-tap voice call to the supervisor directly from the LHW device, without internet |
| Alert Record Sync | connectivity_plus + workmanager (Flutter) | Latest | Local saving of emergency alert records and background synchronisation to the server when internet is available; not required for the SMS and call options |

## Project Stakeholders and Roles

Table 3: Project Stakeholders for MediQore

| Stakeholder | Role | Primary Interaction with System |
|---|---|---|
| District Health Office / LHW Programme Management | Operational and policy-level oversight of the LHW programme | Monitors LHW field performance and area-level health analytics, acts on referral trends, and receives automated PDF and Excel reports for district-wide programme decisions and submission to higher health authorities. |
| Lady Health Worker (LHW) | Primary end user of the mobile application | Registers patients, collects visit data, manages polio campaigns, generates referrals, conducts nutrition and disease screening |
| LHW Supervisor | Uses web dashboard to monitor LHW field activities | Views real-time dashboard, monitors risk alerts, tracks referral outcomes, reviews LHW performance metrics |
| System Administrator | Manages system structure and user accounts | Creates districts, areas, LHW accounts, hospital records; manages roles and audit logs |
| Pregnant Women / Patients | Indirect beneficiaries of the system | Health data is collected and monitored; they receive risk-based care, referrals, and shared patient summaries |
| Hospitals / Referral Centres | Referral destinations for high-risk patients | Appear in the referral system as destination facilities; referral outcomes are recorded against them |
| Children under 5 | Indirect beneficiaries | Vaccination records, nutrition screenings, IMCI assessments, and EPI schedules are recorded and monitored on their behalf. |
| Academic Supervisor | Academic supervision and evaluation | Reviews project progress, evaluates deliverables, and provides technical guidance. |

## Module Based Work Division

Table 4: Team Member Work Division for MediQore

| # | Muhammad Zain Abbas (FA23-BCS-079) | Zain Ali (FA23-BCS-138) | Shared Responsibility |
|---|---|---|---|
| 1 | Module 1: LHW Onboarding & Access Control | Module 5: Emergency Referral Coordination | Backend REST API design and development |
| 2 | Module 2: Pregnant Woman Registration | Module 6: Pregnancy Journey, Health Records & ANC Monitoring | PostgreSQL database schema design |
| 3 | Module 3: Field Visit & Vitals Collection (incl. Voice Guidance) | Module 7: Polio Campaign Field Operations | Offline sync engine (SQLite to server) |
| 4 | Module 4: AI-Based Maternal Risk Assessment | Module 8: Child Immunization & EPI Management | System integration and end-to-end testing |
| 5 | Module 10: Supervisor Dashboard, Reporting & Administration | Module 9: Child Nutrition & Growth Screening | UI/UX design (Figma mockups) |
| 6 | AI model training, validation, and integration (Python / scikit-learn) | Module 10: Supervisor Dashboard, Reporting & Administration (Support) | Deployment, documentation, and final testing |

## WBS and Gantt Chart

Table 5: MediQore Work Breakdown Structure (WBS)

| ID | Phase | Task | Duration | Resources |
|---|---|---|---|---|
| 1 | Analysis | Planning & Requirements Analysis | 8 Weeks | Zain Abbas; Zain Ali |
| 2 |  | Requirements Gathering & Literature Review | 4 Weeks | Zain Abbas; Zain Ali |
| 3 |  | Scope & Proposal Documentation | 4 Weeks | Zain Abbas; Zain Ali |
| 4 |  | Analysis Finished | — |  |
| 5 | Design | UI/UX & System Architecture Design | 8 Weeks | Zain Abbas; Zain Ali |
| 6 |  | UI/UX Design: Mobile App & Web Dashboard (Figma) | 4 Weeks | Zain Abbas; Zain Ali |
| 7 |  | Database Schema Design & Backend API Setup | 4 Weeks | Zain Abbas; Zain Ali |
| 8 |  | Design Finished | — |  |
| 9 | Development | Full-Stack Development of 10 Modules | 16 Weeks | Zain Abbas; Zain Ali |
| 10 |  | Module 1–4: Onboarding, Registration, Field Visit, AI Risk Assessment | 8 Weeks | Zain Abbas |
| 11 |  | Module 5–8: Referral Coordination, Pregnancy Journey, Polio Campaign, EPI Management | 8 Weeks | Zain Ali |
| 12 |  | Module 9: Child Nutrition & Growth Screening | 4 Weeks | Zain Ali |
| 13 |  | Module 10: Supervisor Dashboard & Admin Panel | 4 Weeks | Zain Abbas |
| 14 |  | AI Model Training, Validation & Integration (Python / scikit-learn) | 4 Weeks | Zain Abbas |
| 15 |  | Offline Sync Engine Development & Testing | 2 Weeks | Zain Abbas; Zain Ali |
| 16 |  | Development Finished | — |  |
| 17 | Testing | Comprehensive QA & Validation | 8 Weeks | Zain Abbas; Zain Ali |
| 18 |  | System Integration & Internal Testing | 4 Weeks | Zain Abbas; Zain Ali |
| 19 |  | Final Testing, Bug Fixes & Full Documentation | 4 Weeks | Zain Abbas; Zain Ali |
| 20 |  | Testing Finished | — |  |
| 21 | Completion | Final Release & Presentation | 4 Weeks | Zain Abbas; Zain Ali |
| 22 |  | FYP Final Submission & Presentation | 4 Weeks | Zain Abbas; Zain Ali |
| 23 |  | Project Completed | — |  |

Table 6: MediQore Gantt Chart

*(Image in the Word document; not reproduced here.)*

## Mockups

Mockups for the following screens will be included in the final submission. These will be designed using Figma and cover all major modules. Mockups for Login, Signup, and basic navigation screens are excluded as per template guidelines.

- Mockup 1: Pregnant Woman Registration Screen (Mobile App): Shows the full Urdu registration form with fields for patient name, age, pregnancy month, and obstetric history. Demonstrates the simple, large-button layout and Urdu typography designed for field use without English literacy.
- Mockup 2: Home Visit Data Collection Screen with Voice Guidance (Mobile App): Shows the structured visit form with blood pressure entry, symptom checkboxes in Urdu, the voice guidance microphone indicator, and the offline status indicator showing that data will sync when connectivity is restored.
- Mockup 3: AI Risk Assessment Result Screen (Mobile App): Shows the Red-risk result screen with colour-coded alert banner, Urdu explanation of flagged risk factors (e.g., 'High BP + Swelling detected'), the one-tap referral generation button, and the three-layer emergency alert controls (in-app alert status, SMS, and one-tap call) with the offline “alert not yet delivered” indicator.
- Mockup 4: Polio Campaign House Tracking Screen (Mobile App): Shows the house-by-house vaccination recording screen with household number, children count, vaccinated count, and refusal toggle with reason dropdown; all in Urdu.
- Mockup 5: Child Nutrition & Growth Screening Screen (Mobile App): Shows the MUAC entry screen with automatic SAM/MAM/Normal colour-coded classification result, the Z-score fields, and the IMCI illness checklist entry; demonstrating the combined child health screening flow.
- Mockup 6: Supervisor Web Dashboard (Web App): Shows the main supervisor dashboard with total patients, risk distribution chart, LHW activity table, referral completion rate, and area heatmap; filterable by district and LHW.
Note: Actual mockup images will be attached in Appendix A of the final submission.

## References

National Institute of Population Studies (NIPS) and ICF. Pakistan Demographic and Health Survey 2017-18. Islamabad, Pakistan and Rockville, Maryland, USA: NIPS and ICF, 2019. Internet: https://www.dhsprogram.com/pubs/pdf/FR354/FR354.pdf

M. Ahmed, M. A. Kashem, M. Rahman, and S. Khatun, "Review and Analysis of Risk Factor of Maternal Health in Remote Area Using the Internet of Things (IoT)," Lecture Notes in Electrical Engineering, vol. 632, 2020. Internet: https://archive.ics.uci.edu/dataset/863/maternal+health+risk

UCI Machine Learning Repository. Internet: https://archive.ics.uci.edu/dataset/863/maternal+health+risk

UNICEF. "Performance Evaluation Report: Lady Health Workers Programme in Pakistan." Oxford Policy Management for UNICEF, 2018. Internet: https://www.unicef.org/pakistan/media/3096/file

World Health Organization. "WHO Child Growth Standards: Methods and Development." Geneva: WHO, 2006. Internet: https://www.who.int/publications/i/item/924154693X

World Health Organization. "Integrated Management of Childhood Illness (IMCI) Chart Booklet." Geneva: WHO, 2014. Internet: https://www.who.int/publications/i/item/9789241506823

UNICEF. "Pakistan: Multiple Indicator Cluster Survey 2019, Khyber Pakhtunkhwa." New York: UNICEF, 2020. Internet: https://microdata.worldbank.org/index.php/catalog/5958

World Health Organization. "WHO Recommendations on Antenatal Care for a Positive Pregnancy Experience." Geneva: WHO, 2016. Internet: https://www.who.int/reproductivehealth/publications/maternal_perinatal_health/anc-positive-pregnancy-experience/en/

Free, C., Phillips, G., Galli, L., Watson, L., Felix, L., Edwards, P., and Haines, A. "The Effectiveness of Mobile-Health Technology-Based Health Behaviour Change or Disease Management Interventions for Health Care Consumers: A Systematic Review." PLOS Medicine, vol. 10, no. 1, e1001362, 2013. Internet: https://doi.org/10.1371/journal.pmed.1001362

Onnx Runtime Contributors. "ONNX Runtime: Cross-Platform, High Performance Machine Learning Inferencing." Microsoft, 2023. Internet: https://onnxruntime.ai/

Government of Pakistan, Ministry of National Health Services. "National Health Vision 2016-2025." Islamabad: Ministry of National Health Services, Regulations and Coordination, 2016. Internet: https://www.nhsrc.gov.pk/

Kumar, S., Nilsen, W., Pavel, M., and Srivastava, M. "Mobile Health: Revolutionizing Healthcare Through Transdisciplinary Research." Computer, vol. 46, no. 1, pp. 28-35, 2013. Internet: https://doi.org/10.1109/MC.2012.392

Bhutta, Z.A., Das, J.K., Rizvi, A., Gaffey, M.F., Walker, N., Horton, S., et al. "Evidence-Based Interventions for Improvement of Maternal and Child Nutrition: What Can Be Done and at What Cost?" The Lancet, vol. 382, no. 9890, pp. 452-477, 2013. Internet: https://doi.org/10.1016/S0140-6736(13)60996-4

## Plagiarism Report

*(Scanned image in the Word document; not reproduced here.)*
