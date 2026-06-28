Status: Approved
Phase: 1 — Foundation
Owner: TBD
-->

# SPEC-004 — Asset Loader (GLB / KTX2 / Cache Skeleton)

> Goal · Deliverables · Out of Scope · Risk · Acceptance — Apple Spec style.
> Depends on `spec-001-bootstrap.md` (modules), `spec-003-runtime.md` (Update / Events).

---

## 1. Goal

Provide asynchronous loaders for the engine's first-generation assets:

- **`pets-models/fox.glb`** — embedded Skeleton + Idle animation (D-004 decision).
- **KTX2 textures** (initial: `pets-models/fox.ktx2` — added implicitly by spec, but for Phase 1 use the embedded basis fallback if no KTX2 is shipped).
- **Shader libraries** — `.metal` files compiled at startup.

After SPEC-004 is done, the asset layer can:
1. Load `fox.glb` in <150 ms from disk to a CPU-side representation.
2. Hand off the GLTF buffer to renderer-faced decoders later (texture decode may be deferred).
3. Cache successful loads in a memory cache keyed by content-hash.

---

## 2. Deliverables

- `DPAsset.Loader` module:
  - Public API: `func load(_ url: URL, type: AssetType) async throws -> Asset`.
  - Dispatches to type-specific decoders: `GLBDecoder`, `KTX2Decoder`, `ShaderDecoder`.
  - Errors are typed: `.ioError(underlying:)`, `.decodeError(reason:)`, `.schemaMismatch(field:)`, `.unsupportedVersion`.
- `DPAsset.GLBDecoder`:
  - Uses `glTF-Swift` (or hand-rolled parser — see Risk) to parse the GLB binary.
  - Extracts: mesh primitives, joints, skeleton, embedded buffers, animations, materials.
  - Exposes `Asset.GLB { mesh, skeleton, animations: [Animation], textures: [URI] }`.
  - Validates against `assets/glb-format-spec.md` (D-004 — Skeleton + Animation embedded).
- `DPAsset.KTX2Decoder` (initial version):
  - Reads KTX2 header, defers full GPU upload to render-path.
  - Returns `Asset.KTX2 { width, height, mipCount, format }`.
- `DPAsset.ShaderDecoder`:
  - Loads `.metal` library from `Bundle.module`.
  - Returns `Asset.Shader(sourceHash: ...)` for hot-cache invalidation.
- `DPAsset.MemoryCache`:
  - Key: SHA-256 of file contents.
  - Footprint: capped at 32 MB (Phase 1 budget).
  - Eviction: LRU on full.
- `DPAsset.DiskCache` (skeleton):
  - Persists decoded metadata to `~/Library/Caches/DesktopPet/decoded/`.
  - **Phase 1 does not implement full disk cache** — only the disk-cache interface contract.
- **Tests**:
  - Unit: GLB decoder against a fixture GLB (`tests/Fixtures/fox.glb` — frozen copy of `pets-models/fox.glb`).
  - Schema validation: malformed GLB returns `.schemaMismatch(field:)`.
  - Memory cache: LRU evicts oldest beyond 32 MB.
  - Loader concurrency: 10 parallel `load()` calls of the same URL share one decode (single-flight).
- **API docs**: `api/asset-api.md`.

---

## 3. Out of Scope

- ❌ Draco / Meshopt decoding — Phase 8 may add if compression is needed.
- ❌ Asset authoring tools — assets are checked in.
- ❌ Streaming from network — assets ship bundled.
- ❌ Disk cache full implementation — interface contract only.
- ❌ Asset versioning — Phase 9.
- ❌ Hot-reload of edited .metal files at runtime — Phase 8.
- ❌ LOD / mip generation pipelines — fixed mip chain only.

---

## 4. Risk

| Risk | Mitigation |
|---|---|
| glTF-Swift API surface evolves — pin a commit, not a tag | `Package.swift` pin to a specific revision; CI runs `swift package update` once per milestone. |
| Skeleton + Animation embedded format convention differs from typical glTF | Phase 1 asset spec at `assets/glb-format-spec.md` codifies required channels (joint name, animation channel target path, rest pose); fixture GLB is hashed and any drift fails `spec-005-animation.md` integration test. |
| KTX2 decode library license clash | Choose MIT / BSD-licensed `ktx2-swift` binding; ADR pinned when chosen. |
| Decoder leaks memory under repeated loads | Single-flight + deterministic test asserting memory delta after 100 reloads < 1 MB. |
| Shader `Bundle.module` path differs in Debug vs Release | Validate via `Bundle.main.url(forResource:)` first, fallback to `Bundle.module`. |
| Cache eviction racing with in-flight decode | Hold a decode future in a `singleFlight` dict; eviction respects in-flight references. |

---

## 5. Acceptance

### Performance Metrics
- [ ] `load(fox.glb)` cold **≤ 150 ms** on M-series baseline.
- [ ] `load(fox.glb)` warm (memory hit) **≤ 5 ms**.
- [ ] Memory cache footprint **≤ 32 MB** through 100 reloads.
- [ ] Schema validation overhead **≤ 2 ms** per load.

### Enumerable Use Cases
- [ ] First launch: `load(fox.glb)` produces `Asset.GLB` with one mesh, one skeleton, one animation.
- [ ] Second launch: `load(fox.glb)` returns memory-cached representation (assertion via mock cache hook).
- [ ] Inject corrupt GLB: returns `.decodeError(reason: "...")` — not a crash.
- [ ] Load KTX2: returns `Asset.KTX2 { ... }` without GPU upload yet.
- [ ] Load `Bundle.module/.../Shaders.metal`: returns `Asset.Shader`.

### Assertable States
- [ ] Skeleton node count matches referenced joints exactly (no orphan joints).
- [ ] Animation channels reference valid scene-joint targets.
- [ ] Memory cache eviction orders match LRU.
- [ ] Cache key is SHA-256 of bytes, not file path.
- [ ] Single-flight: 50 concurrent loads of the same key yield **one** decode.

### Previous-Phase Regression
- [ ] `spec-001-bootstrap.md` Logger still emits `info` level for asset-load events.
- [ ] `spec-003-runtime.md` UpdateLoop test still passes when an asset load is in flight.

---

## 6. Trace

- Implements `roadmap.md` D-004.
- Provides `Asset.GLB` consumed by `spec-005-animation.md`.
- API doc: `api/asset-api.md`.
- Asset docs: `assets/fox-model-spec.md`, `assets/glb-format-spec.md`.
