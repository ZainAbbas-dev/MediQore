# Decision records (P0-11)

Roadmap task P0-11 asks the team to settle four open items in Phase 0, so that later phases do not stall (roadmap, "Risks and decisions"). Each record below sets out the evidence, the options and a proposed decision.

**Every record is _Proposed_ until both team members sign it off.** A record that changes the scope's Tools table also needs the supervisor's agreement. To accept a record:

1. Fill in its sign-off table.
2. Change its status to **Accepted**.
3. Update `CLAUDE.md` and the part's `CLAUDE.md` if the decision adds a rule.

| No. | Decision | Status | Still needed from people |
|---|---|---|---|
| [0001](0001-model-inputs.md) | Model inputs: six UCI features, a second model without blood sugar | Proposed | Team sign-off |
| [0002](0002-otp-channel.md) | OTP channel: admin-issued one-time code, behind a swappable OTP service | Proposed | Team sign-off; supervisor check that it meets "OTP verification" (M1 FE-2) |
| [0003](0003-urdu-pdf-method.md) | Urdu PDF reports: HTML printed by headless Chrome (Puppeteer), not pdfkit | Proposed | Team sign-off; supervisor agreement (changes the Tools table) |
| [0004](0004-urdu-voice-source.md) | Urdu voice: phone text-to-speech if the test phones pass the voice check, recorded clips otherwise | Proposed, waiting for phone results | Run the voice check on every test phone |

Evidence lives next to the records:

- the exploratory notebook `ml/notebooks/01_uci_exploration.ipynb` (P0-10);
- the PDF experiment in [`experiments/urdu-pdf/`](experiments/urdu-pdf/);
- the voice check screen in the app (`mobile/lib/screens/voice_check_screen.dart`).
