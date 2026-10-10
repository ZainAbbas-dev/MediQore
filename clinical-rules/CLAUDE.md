# clinical-rules/: the Clinical Rules Table

The one versioned Clinical Rules Table (P0-11, M4 FE-4, LI-12), read by the app and the server. Follow the root `CLAUDE.md` first; `README.md` here describes every section, the condition language and the sign-off steps.

## Key rules

- Every clinical threshold, schedule or classification lives in `clinical-rules.json`, never in Dart, JavaScript or Python code. Code reads the table and stores the `version` it used with each result.
- The table stays `"status": "pending clinical review"` until the Clinical Advisor signs it. Never mark it signed yourself, and never present its values as clinically validated.
- Do not change a value without a reference in `references`. Anything the scope or roadmap does not fix goes in a `review_note` for the Clinical Advisor; list it as a question rather than guessing.
- Any change raises `version`. `db` refuses to load different content under a loaded version.
- After a change, copy the file byte for byte to `mobile/assets/clinical/clinical-rules.json`; tests in `mobile/` and `api/` fail if the copy differs.
- Every rule and flag needs at least one case in `test-cases.json`; the app and the API must pass the same cases.
- Units follow the table's `units` section (BP mmHg, pulse beats/min, temperature °C, blood sugar mmol/L, Hb g/dL, weight kg, MUAC mm, height cm).

## Commands

```powershell
node --test        # from clinical-rules/: table checks and shared test cases (Node.js 24, no dependencies)
```
