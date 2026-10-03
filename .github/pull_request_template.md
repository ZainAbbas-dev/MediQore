<!--
Title: start with the scope ID, for example "M3 FE-2: outbox and sync push".
Base branch: dev. Only the dev → main pull request targets main.
-->

## Scope ID

<!-- For example M3 FE-2, plus the roadmap task if there is one (for example P0-6). -->

Closes #

## What changed

## How it was tested

<!-- Tests added or run; for mobile, whether it was checked on a real phone in airplane mode. -->

## Definition of done

<!-- From docs/roadmap.md. A module counts as finished only when every item is true. Tick what is true after this PR; mark items that do not apply to this change as "n/a". -->

- [ ] Every FE in the scope document for that module works on a real Android phone
- [ ] Works fully offline where the scope says so, and syncs correctly afterwards
- [ ] All screens in Urdu with no text overflow; numeric values display left to right
- [ ] API routes validated with Joi, role-checked and area-scoped
- [ ] Every create, edit and delete writes an audit row
- [ ] Unit and API tests written and passing in CI
- [ ] Module 10 shows the module's data (dashboard, map or report, as the scope says)
- [ ] Synthetic data for the module added to the seed script
- [ ] Reviewed and merged by the other team member
- [ ] Short note added to the user guide and test report

## Project rules

- [ ] Scope ID in the PR title and in a comment at the feature's main entry point
- [ ] No secrets committed (`.env` files, keys, keystores, service-account files)
- [ ] Synthetic data only, no real patient data (LI-10)
