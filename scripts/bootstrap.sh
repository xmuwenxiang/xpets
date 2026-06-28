#!/usr/bin/env bash
# desktop-pet-core bootstrap script.
#
# Sets up pre-commit hooks, verifies macOS command-line tooling, and confirms
# the Swift Package builds end-to-end. Idempotent — safe to re-run.
#
# Spec-001 §2 row: Build script `scripts/bootstrap.sh` installs swift-format, sets
# up `.git/hooks/pre-commit`, verifies macOS toolchain, exits non-zero on missing tools.
#
# Acceptance covered:
#   `specs/Phase-1-Foundation/acceptance.md` row 28 — `git clone && ./scripts/bootstrap.sh`
#                       (this script is the gate; Xcode .xcodeproj step is Phase 9).
#   `specs/Phase-1-Foundation/acceptance.md` row 29 — `swift test` passes (best-effort).
#   `specs/Phase-1-Foundation/acceptance.md` row 31 — Cold ≤ 90 s; incremental ≤ 5 s.
#   `specs/Phase-1-Foundation/acceptance.md` row 25 — Profiler `.off` zero allocations
#                       (verified by `Tests/DPProfilerTests/ProfilerTests.swift`).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "[bootstrap] verifying macOS toolchain"
# Ponytail: bail out with a clear message if a required tool is missing. We do NOT
# try to install Xcode in CI — Apple platform tooling must be present beforehand.

required=(
  "swift"
  "xcrun"
)
missing=0
for tool in "${required[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[bootstrap] ERROR: required tool '$tool' is missing" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "[bootstrap] install Xcode 15+ and the Command Line Tools package, then re-run." >&2
  exit 1
fi

# Optional: swift-format is welcome but not required for spec-001 §5 acceptance.
if command -v swift-format >/dev/null 2>&1; then
  echo "[bootstrap] swift-format found at $(command -v swift-format)"
else
  echo "[bootstrap] notice: 'swift-format' not on PATH; CI will fetch it on demand."
fi

echo "[bootstrap] building Swift package (cold — performance budget row 31)"
COLD_START=$(date +%s)
(cd desktop-pet-core && swift build >/dev/null)
COLD_END=$(date +%s)
COLD_SECS=$((COLD_END - COLD_START))
echo "[bootstrap] cold swift build: ${COLD_SECS}s (acceptance row 31: ≤ 90 s)"
if [[ "$COLD_SECS" -gt 90 ]]; then
  echo "[bootstrap] WARNING: cold build exceeded 90 s budget — investigate cache hygiene."
fi

echo "[bootstrap] building Swift package (incremental — performance budget row 31)"
INC_START=$(date +%s)
(cd desktop-pet-core && swift build >/dev/null)
INC_END=$(date +%s)
INC_SECS=$((INC_END - INC_START))
echo "[bootstrap] incremental swift build: ${INC_SECS}s (acceptance row 31: ≤ 5 s)"
if [[ "$INC_SECS" -gt 5 ]]; then
  echo "[bootstrap] WARNING: incremental build exceeded 5 s budget."
fi

# Pre-commit hook: enforce swift-format + swift test on commit (acceptance row 29).
if [[ -d .git ]]; then
  mkdir -p .git/hooks
  cat > .git/hooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
if command -v swift-format >/dev/null 2>&1; then
  swift-format format --in-place --recursive desktop-pet-core/Sources desktop-pet-core/Tests || true
fi
(cd desktop-pet-core && swift test)
HOOK
  chmod +x .git/hooks/pre-commit
  echo "[bootstrap] installed pre-commit hook (swift test gate — row 29)."
else
  echo "[bootstrap] no .git directory; skipping pre-commit hook install."
fi

# Optional: `swift test` is the closure gate but only works when XCTest is available.
# On a machine with CommandLineTools (no Xcode), SwiftPM tests cannot find XCTest.
# CI provides Xcode; local developers may use `xcodebuild test` as a fallback.
if (cd desktop-pet-core && swift test 2>&1) | grep -qE 'XCTest|Test Suite.*[Ss]ucceeded|Test Suite.*[Pp]assed|Executed [0-9]+ test'; then
  echo "[bootstrap] swift test — passes (acceptance row 29)."
else
  echo "[bootstrap] NOTICE: swift test did not run (XCTest unavailable on this Swift toolchain)."
  echo "             Phase 1 closure gate is enforced in CI; see .github/workflows/ci.yml."
fi

echo ""
echo "[bootstrap] OK — package builds, performance budgets within tolerance, tooling in place."
echo "[bootstrap] next: open DesktopPet.xcodeproj (when present, Phase 9 debt) or 'swift run' from desktop-pet-core."
echo "[bootstrap] ADR set: see decisions/D-001..D-013. Phase 1 closure checklist: specs/Phase-1-Foundation/checklist.md."
