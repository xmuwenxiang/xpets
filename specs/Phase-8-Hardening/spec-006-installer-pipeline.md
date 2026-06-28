<!--
Status: Draft
Phase: 8 — Hardening
-->


# SPEC-006 — Installer Pipeline (DMG / Signed / Notarized)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Ships a `.dmg` that boots out-of-the-box on Apple Silicon.

---

## 1. Goal

Produce a notarized, signed `.dmg` installer ≤ 30 MB. After SPEC-006 ships, a user can download the `.dmg`, drag the app to `/Applications`, launch, and pass first-day wizard.

---

## 2. Deliverables

- `scripts/installer.sh` (or CI equivalent):
  - Build in `--release` mode.
  - Strip debug symbols.
  - Run `codesign --deep --options=runtime --sign "Developer ID Application: …"`.
  - Run `notarytool submit --wait`.
  - Staple.
  - Produce `.dmg`.
- Size budget enforced in CI:
  - Pre-archive size ≤ 25 MB.
  - Final `.dmg` ≤ 30 MB.
- Tests:
  - CI smoke: installer built, signed, notarized, sized below 30 MB.
  - Manual user flow: install → launch → wizard (manual review).

---

## 3. Out of Scope

- ❌ Auto Update — Phase 9.
- ❌ Telemetry — Phase 9.

---

## 4. Risk

- **Notarization reject** on first try — Mitigation: validated `entitlements.plist` + hardened runtime.
- **DMG size growth** — Mitigation: STRIP + Asset format on-demand.

---

## 5. Acceptance (D-013 — 4 categories)

### Performance metric

- Installer size ≤ 30 MB.

### Enumerable

- CI built installer.
- Manual install → boot → wizard works.

### Assertable

- Codesign signature verified.
- Notarization ticket stapled.

### Regression

- Phase 1..7 Acceptance still pass.
