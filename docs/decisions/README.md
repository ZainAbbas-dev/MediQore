# Decision records

These records settle the open items of the earlier roadmap's Phase 0 (its task P0-11), so later phases did not stall. Each sets out the evidence, the options and a decision. The updated final scope and the roadmap of 10 Oct 2026 have since decided most of them; each record starts with an **Update, 2026-10-10** note that says how.

- An **Accepted** record binds like the roadmap.
- A **Proposed** record is not decided yet: ask before building on it. To accept one, fill in its sign-off table, change its status to **Accepted** and update `CLAUDE.md` and the part's `CLAUDE.md` if it adds a rule. A record that changes the scope's Tools table also needs the supervisor's agreement.
- A **Superseded** or **Withdrawn** record is kept as history.

| No. | Decision | Status | Still needed from people |
|---|---|---|---|
| [0001](0001-model-inputs.md) | Model inputs: a five-feature model by default and a six-feature model with a same-visit blood sugar | **Accepted** (decided in the updated scope, M3 FE-1, M4 FE-1) | — |
| [0002](0002-otp-channel.md) | First login on a phone: admin-issued code | **Superseded** by the scope's activation code (M1 FE-2); the built code is replaced in the Phase 1 revision | — |
| [0003](0003-urdu-pdf-method.md) | Urdu PDF reports: HTML printed by headless Chrome, because pdfkit runs Urdu lines left to right (roadmap P0-12) | Proposed; the roadmap's own rule picks this fallback | Team sign-off; supervisor agreement (changes the Tools table); settle by 27 Dec 2026 |
| [0004](0004-urdu-voice-source.md) | Urdu voice source | **Withdrawn**: voice guidance is out of scope (LI-6) | — |
| [0005](0005-language-switch.md) | Urdu/English language switch | **Accepted**, now part of the scope (M3 FE-3); its voice rule is void | — |
| [0006](0006-database-encryption-library.md) | Encrypted local database: SQLite3 Multiple Ciphers through Drift | **Accepted** for the library (scope Tools table); its password-derived key is superseded by the Keystore-wrapped random key (M3 FE-2, LI-8) | — |

Evidence lives next to the records:

- the exploratory notebook `ml/notebooks/01_uci_exploration.ipynb` (P0-10);
- the PDF experiment in [`experiments/urdu-pdf/`](experiments/urdu-pdf/) (P0-12).

The Clinical Rules Table (roadmap P0-11 now) is not a decision record: it lives in [`clinical-rules/`](../../clinical-rules/README.md), marked "pending clinical review" until the Clinical Advisor signs it.
