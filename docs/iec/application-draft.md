# Application for ethical review: MediQore usability evaluation with Lady Health Workers

**Draft for the COMSATS University Islamabad Institutional Ethical Committee (IEC).** Copy each section into the committee's official form. Placeholders are in **[square brackets]**, and choices for the team are marked **[Decide]**.

## 1. Project and applicants

| Item | Detail |
|---|---|
| Project title | MediQore: an AI-assisted, offline-capable Urdu digital health platform for Lady Health Workers in Pakistan |
| Type | Final-year project, BS Computer Science |
| Department | [Department of Computer Science, COMSATS University Islamabad, campus] |
| Student investigators | Muhammad Zain Abbas, [registration number]; Zain Ali, [registration number] |
| Supervisor | Ma'am Sajida Kalsoom, [designation, department, email] |
| Contact for participants | [supervisor's or department's official email and phone] |
| Planned dates of the activity | [dates], project week 26 of 28 ([FYP-II semester]) |
| Funding | None |
| Conflicts of interest | None |

Registration numbers and personal contact details belong only on the submitted form, never in the public repository.

## 2. Summary in plain language

Lady Health Workers (LHWs) keep maternal and child health records on paper. MediQore is a student-built prototype that replaces these registers with:

- an Urdu Android app that works without internet;
- a web dashboard for supervisors.

The app also gives a maternal risk result (Green, Yellow or Red) from an on-device machine-learning model, as decision support only.

We ask for approval for **one activity**: a short usability evaluation in which a small number of LHWs and LHW supervisors try the prototype and tell us how easy it is to use. Specifically:

- they look at the Urdu screens, listen to the Urdu voice guidance and complete set tasks;
- they use **made-up (synthetic) patient records only**;
- **no real patient information is entered, collected or seen**;
- we record task results and their opinions, without names.

## 3. Background and rationale

- Pakistan's LHWs document maternal and child health work in paper registers. The records are easily lost, incomplete and invisible to supervisors (scope, Problem Statement).
- MediQore targets LHWs who may have limited English and limited experience with smartphones. Whether the Urdu interface, the Nastaliq text, the large controls and the voice guidance actually work for them can only be judged by LHWs themselves.
- Feedback from engineering students cannot substitute for this.

## 4. Objectives of the activity

1. Measure whether LHWs can complete the core field tasks in the prototype without help: register a pregnant woman, record a home visit, read a risk result and raise an emergency alert.
2. Find usability problems in the Urdu interface, including text size, Nastaliq readability, layout on small phones and the clarity of the voice guidance.
3. Find out whether the risk result and its Urdu explanation are understood as decision support, not a diagnosis (LI-5).
4. Collect supervisors' views on the dashboard's usefulness.

## 5. Scope of this application

| Activity | Included? |
|---|---|
| Usability sessions with LHWs and supervisors, synthetic data only | **Yes** |
| Use of the public, de-identified UCI Maternal Health Risk dataset to train the model | Declared for completeness: it is secondary public data with no identifiers (CC BY 4.0) |
| Use of published PDHS 2017–18 summary statistics | Declared for completeness: published aggregate figures |
| Collecting or processing **real patient data** | **No.** The prototype is developed and demonstrated on synthetic data only (LI-10). Collecting field data for future model retraining (LI-2) would need a separate application or an amendment. |

**[Decide]** Confirm that the application covers only the usability evaluation. If the team plans any other contact with LHWs before Phase 4, add it here, for example reviewing the Figma screens with LHWs. The scope says requirements were gathered through consultations with LHWs and supervisors; ask the supervisor whether that earlier activity needs to be declared.

## 6. Participants

- **Who:**
  - currently serving LHWs;
  - LHW supervisors (Lady Health Supervisors) or other supervisors of LHWs.
- **How many:** [Decide] for example 5–8 LHWs and 2–3 supervisors. Small groups like this find most usability problems, and the burden on the health system stays low.
- **Inclusion criteria:**
  - aged 18 or over;
  - currently working as an LHW or a supervisor of LHWs;
  - reads Urdu;
  - willing to take part.
- **Exclusion criteria:**
  - anyone who does not give consent;
  - anyone unable to attend during working arrangements agreed with the health office.
- **Where:** [Decide: district]. A health facility room or the LHWs' regular meeting place, during [Decide: a monthly meeting or a separate appointment].
- **Recruitment:**
  1. After written permission from [District Health Authority / provincial LHW Programme office], the team gives an invitation and the information sheet to eligible LHWs through [the office or the facility in-charge].
  2. LHWs reply directly to the team.
  3. Supervisors are not told who declined, so nobody feels pressure from their line manager.
- **Payment:** [Decide] none, or refreshments and travel costs only. No payment large enough to pressure anyone.

## 7. Procedure

Details are in [`usability-protocol.md`](usability-protocol.md). In short:

1. **Consent.** The facilitator explains the study in Urdu, reads the information sheet aloud on request, answers questions and takes written consent. A thumb impression with a witness is accepted if preferred.
2. **Background questions** (about 5 minutes): age range, years of service, and how often the participant uses a smartphone. No name is recorded on the data sheets; each participant gets a code (P01, P02 …).
3. **Tasks** (about 30 minutes) on a project test phone in airplane mode, with synthetic patients only.
   - The observer notes completion, time, errors and comments.
   - Emergency SMS and calls go only to a team-held test phone, never to a real supervisor.
4. **Questionnaire** (about 10 minutes) in Urdu: ease of use, readability, voice guidance, understanding of the risk result. Then a short open discussion.
5. Total time is about 45–60 minutes. Participants may stop at any time.

**[Decide]** Audio or screen recording. The draft assumes **no audio or video recording of participants**; written notes only. A screen recording of the test phone, which shows synthetic data only, would need its own consent box.

## 8. Risks and how they are reduced

| Risk | Mitigation |
|---|---|
| Time taken from health work | Short sessions, scheduled with the health office at a convenient time |
| Feeling judged when a task is hard | The facilitator explains that we are testing the app, not the participant. No individual results are shared with supervisors or the health department. |
| Feeling obliged to take part because the invitation comes through the health system | Voluntary participation. The decision is not reported to supervisors. Participants may withdraw without giving a reason, and it does not affect their job. |
| Gender and cultural comfort: the student investigators are men, and LHWs are women | [Decide] A female facilitator or observer (for example a female classmate or the facility's female staff) present at every LHW session; the session held in a public facility room; the participant may bring a colleague |
| Confidentiality of opinions | No names on data sheets, coded IDs, consent forms stored apart from data, results reported only in aggregate |
| Mistaking the risk result for medical advice | Only synthetic patients are used. The app and the facilitator state that the AI result is decision support, not a diagnosis (LI-5). |
| Emergency alerts reaching real people | Alerts go only to the team's test phone; the test phones contain synthetic data only |

Overall risk: **minimal.** The activity is comparable to everyday training on a new tool.

## 9. Data management

- **Collected:**
  - consent forms;
  - coded background answers;
  - task observation sheets;
  - questionnaire answers;
  - the facilitator's notes.
- **Not collected:**
  - patient data of any kind;
  - participants' phone numbers beyond scheduling;
  - photographs or recordings, unless agreed under [Decide] above.
- **Storage:**
  - Paper forms go in a locked place at [the department / supervisor's office].
  - Electronic data goes in [Decide: an encrypted university storage location]. It is never kept in the project's public GitHub repository.
  - Consent forms are kept apart from coded data.
- **Access:** the two student investigators and the supervisor.
- **Retention:** [Decide: per university policy, for example until the degree result plus N years], then destroyed.
- **Reporting:** only aggregate and anonymised results appear in the final-year report and any presentation. Quotations are used without names or identifying details.

## 10. Consent

The information sheet and consent form are attached ([`participant-information-sheet.md`](participant-information-sheet.md), [`consent-form.md`](consent-form.md)).

- Both will be given in Urdu, the participants' working language. A team member translates them and a second Urdu reader checks the translation.
- Consent is taken before any activity.
- Participants keep a copy of the information sheet.
- Participants may withdraw during the session. Afterwards, their coded data can be removed until [date: analysis cut-off].

## 11. Benefits

- No direct benefit to participants beyond trying a new tool.
- Their feedback helps make a tool that suits LHWs' work. Making that tool is the purpose of the project.

## 12. Timeline

| When | Step |
|---|---|
| Project weeks 1–2 (Phase 0) | Application drafted and submitted |
| [dates] | IEC review |
| [date] | Permission letter from the health office |
| Project week 26 (Phase 4) | Usability sessions, only after IEC approval |
| Project weeks 27–28 | Analysis and final report |

If approval has not arrived by week 26, the usability check runs with fellow students on synthetic data only, as the project plan says (roadmap, Phase 4). No LHW is approached before approval.

## 13. Declarations

- No real patient data will be collected or processed in this project (LI-10). All app data is synthetic.
- The AI output is decision support only and is not used for any clinical decision (LI-5).
- Any change to the activities above will be submitted to the IEC as an amendment before it starts.

| Name | Role | Signature | Date |
|---|---|---|---|
| Muhammad Zain Abbas | Student investigator | | |
| Zain Ali | Student investigator | | |
| Ma'am Sajida Kalsoom | Supervisor | | |
