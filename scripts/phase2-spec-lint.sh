#!/usr/bin/env bash
# scripts/phase2-spec-lint.sh
#
# Phase 2 spec health gate. Mirrors 00-spec-conventions.md §10 (no TBD) and
# §7 (Approved = implementation gate). Also enforces acceptance.md +
# checklist.md parity with Phase 1 (§4.1/§4.2) and the D-013 4-category rule.
#
# Scope: only the 6 canonical spec files (overview + spec-001..005).
# execution-plan.md / acceptance.md / checklist.md may legitimately mention
# "TBD" descriptively and are excluded.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
PHASE="specs/Phase-2-Rendering"

# Canonical spec files only.
FILES=(
  "$PHASE/overview.md"
  "$PHASE/spec-001-metal-renderer.md"
  "$PHASE/spec-002-material-pbr.md"
  "$PHASE/spec-003-lighting.md"
  "$PHASE/spec-004-shadow.md"
  "$PHASE/spec-005-hdr-post.md"
)

fail=0

# 1. No TBD anywhere in canonical specs (§10).
if grep -rn 'TBD' "${FILES[@]}"; then
  echo "::error::TBD forbidden in canonical Phase-2 specs (00-spec-conventions.md §10)"
  fail=1
fi

# 2. No de-placeholder marker (resolved at review pass).
if grep -rn 'placeholder — to be expanded' "${FILES[@]}"; then
  echo "::error::placeholder marker still present in canonical Phase-2 specs"
  fail=1
fi

# 3. Each Work Spec carries a 'Status: Approved' header line (§7).
for spec in "$PHASE"/spec-*.md; do
  if ! grep -q '^Status: Approved$' "$spec"; then
    echo "::error::$spec missing 'Status: Approved' header line"
    fail=1
  fi
done

# 4. overview carries an Approved status value (must match the blockquote
#    status prefix `> **Status**: **Approved`, not the word "Approved"
#    appearing in prose — the §7 cross-ref mentions `Status: Approved`).
if ! grep -q '> \*\*Status\*\*: \*\*Approved' "$PHASE/overview.md"; then
  echo "::error::overview.md missing Approved status"
  fail=1
fi

# 5. acceptance.md + checklist.md present (§4.1/§4.2 parity with Phase 1).
for f in acceptance.md checklist.md; do
  if [[ ! -f "$PHASE/$f" ]]; then
    echo "::error::$PHASE/$f missing"
    fail=1
  fi
done

# 6. acceptance.md carries all 4 D-013 categories.
for cat in 'Performance' 'Enumerable' 'Assertable' 'Regression'; do
  if ! grep -q "$cat" "$PHASE/acceptance.md"; then
    echo "::error::acceptance.md missing D-013 category: $cat"
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "phase2-spec-lint: FAIL"
  exit 1
fi
echo "phase2-spec-lint: PASS"
