# Usability session protocol (Phase 4, week 26)

This is the session plan for the roadmap's "Usability check of the Urdu interface and voice guidance". It runs with LHWs and supervisors only after IEC approval; until then, the same plan runs with fellow students. Tasks use only features already built and synthetic data from the generator (P0-8).

## Before the session

- Two charged test phones with the release APK, loaded with synthetic data (`npm run seed:synthetic`). Use the smallest phone the team has, because Nastaliq text overflows first on small screens.
- Airplane mode on: LHWs work offline.
- The supervisor role's emergency number points to a **team-held test phone**, never a real supervisor.
- Printed: information sheets, consent forms, an observation sheet for each participant, questionnaires (Urdu).
- Roles: a facilitator, who speaks and helps only when the participant is stuck, and an observer, who writes. [Decide: a female team member present at every LHW session.]

## Session (about 45–60 minutes)

1. Welcome, information sheet, questions, consent (10 minutes).
2. Background questions (5 minutes):
   - age group (18–29, 30–39, 40–49, 50+);
   - years as an LHW or supervisor;
   - smartphone use (never, sometimes, daily);
   - has used any health app before (yes or no).
3. Tasks (30 minutes). The facilitator reads each task in Urdu. The participant may think aloud.
4. Questionnaire and short discussion (10–15 minutes).

## Tasks for LHWs

Use only tasks for features that work by week 26. The scope ID shows where each task comes from.

| No. | Task | Scope |
|---|---|---|
| 1 | Sign in with the given test account | M1 FE-2 |
| 2 | Register this (made-up) pregnant woman from the card we give you, including her household location | M2 FE-1–3 |
| 3 | Record a home visit with the vitals on the card; turn voice guidance on and off | M3 FE-1, FE-3 |
| 4 | Read the risk result and say in your own words what it means and what you would do | M4 FE-1, FE-2 |
| 5 | The card shows danger signs: raise an emergency alert using any option you choose | M4 FE-4, M5 FE-2 |
| 6 | Find the woman from task 2 in the patient list | M2 FE-3 |
| 7 | Record a polio campaign visit to a household | M7 |
| 8 | Check which child in the list has missed a vaccination | M8 |
| 9 | Record a child's MUAC measurement | M9 |

## Tasks for supervisors

| No. | Task | Scope |
|---|---|---|
| 1 | Sign in to the dashboard and find how many women are registered in your areas | M10 FE-1 |
| 2 | Find the high-risk women on the map | M10 FE-1 |
| 3 | Open the emergency alert raised in the LHW session and acknowledge it | M5 |
| 4 | Download last week's report | M10 FE-2 |

## Observation sheet (for each task)

| Task | Completed without help / with help / not completed | Time (min:sec) | Errors or hesitations | Comments (what the participant said) |
|---|---|---|---|---|
| 1 | | | | |

## Questionnaire outline (Urdu, 5-point scale: strongly disagree to strongly agree)

**[Decide]** Use the standard System Usability Scale (10 items) translated into Urdu, plus the items below, or the items below only.

1. The Urdu text was easy to read.
2. The text and buttons were big enough.
3. The voice guidance was clear and helped me fill in the form.
4. I understood what the Green, Yellow and Red results mean.
5. I understood that the risk result is a help, not a doctor's diagnosis.
6. I could send an emergency alert quickly.
7. I would like to use this app in my daily work.

Open questions:

- What was the most difficult part?
- What is missing that you need in your work?
- Anything else?

## After the session

- Store the forms and notes as set out in section 9 of the application. **Nothing goes into the repository.**
- Turn the problems found into GitHub issues without participant details, labelled by module.
- Summarise the results (completion rates, common problems, questionnaire averages) for the test report.
