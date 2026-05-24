<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# The current-version cascade

> The documented procedure behind the **landscape-researcher** agent (spec §4b.3) — the reverse-engineer suite's differentiator. For every detected dependency / runtime, it establishes **current** ground truth from **live sources**, never from stale model training knowledge. This reference is the contract the agent follows and the runbook a human follows to reproduce or audit a finding.
>
> **The non-negotiable rule:** every version, status, CVE, and current-API claim carries a **live source** (the tool/API that produced it this run) + a **confidence** (`high`/`low`). A source that is unreachable is reported as such and marked `low`, or the cell becomes **"could not verify against current sources"** — it is **never** backfilled from memory. Detected tech almost always post-dates the model's training cutoff, so a remembered version is, by default, wrong.

All endpoints below are public and free (no auth required for the read paths used here). Send only package **names + versions** — never anything from the target's secrets. Run any CLI **read-only**, scoped to the target.

---

## Step 1 — Inventory: `{ecosystem, name, pinned}`, ecosystem-agnostic

**Preferred — `syft` → CycloneDX SBOM** (`command -v syft`):

```bash
syft <target_root> -o cyclonedx-json > sbom.cdx.json
```

Produces a CycloneDX SBOM listing every component across every manifest `syft` finds, uniformly as `{ecosystem (purl), name, version}` — no per-language special-casing. The SBOM file is also the input to `grype` in step 3. (`syft … -o spdx-json` is an equivalent SBOM format if SPDX is preferred downstream.)

**Fallbacks (no `syft`)** — still live, never memory:
- Consume **dependency-mapper's external-dependency inventory** (it already extracted `{name, ecosystem, pinned, file:line}` from the manifests/lockfiles).
- Or parse the lockfiles directly for the **resolved** pin: `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` (npm), `Cargo.lock` (cargo), `poetry.lock` / `requirements.txt` (PyPI), `go.sum` (Go), `Gemfile.lock` (RubyGems), `composer.lock` (Packagist), `packages.lock.json` (NuGet).

Always research the **concrete pinned version** (the lockfile-resolved one where available) — CVEs and versions-behind are only meaningful against a concrete version, not a spec range.

---

## Step 2 — Current stable + versions_behind: **deps.dev**

deps.dev (Google's Open Source Insights) is ecosystem-agnostic and authoritative for "what is the current stable version of this package."

**All versions of a package:**
```
GET https://api.deps.dev/v3/systems/{SYSTEM}/packages/{name}
```
The response is `versions[]`; the version whose **`isDefault: true`** is the **current stable** version. (deps.dev sets `isDefault` to the registry's notion of the default/latest stable release — e.g. npm's `latest` dist-tag, PyPI's latest non-prerelease.)

**A specific version (also returns advisories — used in step 3):**
```
GET https://api.deps.dev/v3/systems/{SYSTEM}/packages/{name}/versions/{version}
```
Includes `advisoryKeys[]` — security advisories known to affect that exact version (cross-checks OSV).

### `{SYSTEM}` enum (UPPERCASE in the path)

deps.dev requires the package-system enum in UPPERCASE in the URL path:

| Detected ecosystem | `{SYSTEM}` |
|---|---|
| npm | `NPM` |
| PyPI | `PYPI` |
| crates.io / cargo | `CARGO` |
| Go modules | `GO` |
| Maven / Gradle | `MAVEN` |
| NuGet | `NUGET` |
| RubyGems | `RUBYGEMS` |

**URL-encode `{name}`**: scoped npm packages (`@scope/pkg` → `%40scope%2Fpkg`) and Maven coordinates (`group:artifact`) must be percent-encoded.

```bash
# Example: current stable of express (npm)
curl -fsS "https://api.deps.dev/v3/systems/NPM/packages/express" \
  | jq -r '.versions[] | select(.isDefault == true) | .versionKey.version'
```

### Compute `versions_behind`

From the pinned version to the `isDefault` current stable, express the gap as the semver deltas — e.g. "**2 majors behind**" (4.18.2 → 5.1.0) or "**11 minors behind**". This is the headline risk number.

### Corroborating / fallback registries (cross-check, or deps.dev unreachable)

Each is a live source; two agreeing sources → `confidence: high`:

| Ecosystem | Endpoint | Current-stable field |
|---|---|---|
| npm | `GET https://registry.npmjs.org/{name}` | `dist-tags.latest` |
| PyPI | `GET https://pypi.org/pypi/{name}/json` | `info.version` |
| crates.io | `GET https://crates.io/api/v1/crates/{name}` | `crate.max_stable_version` |

---

## Step 3 — Vulnerabilities (CVEs on the concrete pinned version)

**Preferred — `grype` over the SBOM** (`command -v grype`):

```bash
grype sbom:sbom.cdx.json -o json   # the CycloneDX file from step 1
```
Returns matched vulnerabilities per component, each with severity + **fixed-version** (the upgrade target).

**OSV — the canonical free vuln DB over HTTP (always available):**
```
POST https://api.osv.dev/v1/query
Content-Type: application/json

{ "package": { "name": "<name>", "ecosystem": "<ECOSYSTEM>" }, "version": "<pinned>" }
```
Returns `vulns[]` affecting that exact version. (A commit may be queried instead with `{ "commit": "<sha>" }`.)

**OSV ecosystem casing is case-sensitive (PascalCase / canonical):** `npm`, `PyPI`, `crates.io`, `Go`, `RubyGems`, `Maven`, `NuGet`, `Packagist`, `Pub`, `Hex` — note this is **different** from deps.dev's UPPERCASE `{SYSTEM}`. Use `npm` (lowercase) and `PyPI`/`crates.io`/`RubyGems` exactly.

```bash
curl -fsS -X POST "https://api.osv.dev/v1/query" \
  -H "Content-Type: application/json" \
  -d '{"package":{"name":"lodash","ecosystem":"npm"},"version":"4.17.20"}' \
  | jq -r '.vulns[]?.id'
```

**deps.dev `advisoryKeys[]`** (from the specific-version endpoint in step 2) is a third cross-check.

Report each CVE as **id + severity + fixed-version**. If every source is unreachable: **"could not verify CVEs against current sources"** — never "no known CVEs" from memory.

---

## Step 4 — End-of-life: **endoflife.date** (runtimes, frameworks, DBs, OSes)

```
GET https://endoflife.date/api/v1/products/{product}
```
Returns the product's release cycles, each with its EOL date (the `eol` field — a date string, or `true`/`false`). Flag the detected version's cycle as **past-EOL** (EOL date in the past) or **nearing-EOL** (e.g. within ~6 months).

```
GET https://endoflife.date/api/v1/products
```
Lists valid product slugs — map the detected runtime/framework to its slug.

| Detected | `{product}` slug |
|---|---|
| Node.js | `nodejs` |
| Python | `python` |
| PHP | `php` |
| Ruby | `ruby` |
| PostgreSQL | `postgresql` |
| Django | `django` |
| Ubuntu | `ubuntu` |

```bash
# Example: is the detected Node major past EOL?
curl -fsS "https://endoflife.date/api/v1/products/nodejs" \
  | jq -r '.result.releases[] | "\(.name): eol \(.eolFrom // .eol)"'
```

This is the step that turns "Node 16" into "**Node 16 — past EOL; upgrade to an active LTS**". Most libraries are **not** covered by endoflife.date — a missing product simply gets no EOL flag (expected, not a gap). endoflife.date tracks runtimes, frameworks, databases, and OSes.

---

## Step 5 — Doc confirmation for headline frameworks (avoid hallucinated APIs)

For the **few headline frameworks** design-recovery will reason about in detail (the web framework, the ORM, the primary UI library) — not every transitive dep — confirm the **current major's actual API shape** so no stale/hallucinated API reaches the recovered design.

1. **context7 MCP** (if available): `resolve-library-id` → `query-docs` for the current major's API surface. `(via context7)`
2. **Vendor `llms.txt` first** (mirrors project-architect's research-scout universal checklist): `WebFetch https://<docs-root>/llms.txt` and `/llms-full.txt`; if absent, the docs index. `(via WebFetch <url>)`
3. **WebSearch** the current-major delta: `"<framework> <currentmajor> migration"`, `"<framework> deprecation"`, `"<framework> superseded"`. `(via WebSearch)`

Capture: the current major, breaking changes from the detected major, and any deprecation/superseded notice (e.g. "Moment.js — maintenance mode; project recommends Luxon/date-fns"). This is how tech **newer than the model's training cutoff** still gets described correctly.

---

## Per-row output — the cross-agent contract

landscape-researcher emits one row per dependency/runtime, **column-compatible with dependency-mapper's annotation table** so the skill merges them into a single `docs/reverse-engineer/DEPENDENCIES.md`. dependency-mapper published `Dependency | Ecosystem | Pinned (file:line) | Current stable | Status | CVEs | Source` and left `versions_behind` + `confidence` to landscape-researcher; the reconciled merged shape is:

| Column | Filled by | Source |
|---|---|---|
| `name` | dependency-mapper | manifest/lockfile |
| `ecosystem` | dependency-mapper | manifest/lockfile |
| `pinned` (`file:line`) | dependency-mapper | manifest/lockfile (verified `is`) |
| `current_stable` | landscape-researcher | **deps.dev `isDefault`** (+ registry corroboration) |
| `versions_behind` | landscape-researcher | computed (pinned → current_stable) |
| `status` | landscape-researcher | endoflife.date + doc confirmation → `current`/`deprecated`/`superseded`/`EOL` |
| `CVEs` | landscape-researcher | grype / OSV / deps.dev advisoryKeys |
| `source` | landscape-researcher | the tool/api that produced the row |
| `confidence` | landscape-researcher | `high`/`low` per the never-stale rule |

Cross-agent flow: **dependency-mapper inventories → landscape-researcher researches status (this cascade) → design-recoverer consumes the merged table** (the supply surface with researched versions, EOL flags, and CVEs).

---

## Provenance + graceful degradation (summary)

| Capability | INVOKE (probe `command -v` / MCP) | EMULATE (still live, never memory) | Provenance tag |
|---|---|---|---|
| Inventory | `syft -o cyclonedx-json` | dependency-mapper inventory / parse lockfiles | `(via syft)` / `(via lockfile)` |
| Current stable | deps.dev `isDefault` | npm dist-tags / PyPI `/json` / crates.io | `(via deps.dev)` / `(via npm registry)` … |
| Vulns | `grype sbom:` | OSV `/v1/query` / deps.dev `advisoryKeys[]` | `(via grype)` / `(via OSV)` |
| EOL | endoflife.date `/api/v1/products/{product}` | — (no offline equivalent) | `(via endoflife.date)` |
| Doc confirm | context7 | vendor `llms.txt` / WebFetch / WebSearch | `(via context7)` / `(via WebFetch …)` |

Tool availability is **host-specific** — never assume, always probe. Every external source is best-effort: probe → invoke → else the next live source → else **"could not verify against current sources"**. The path that produced each finding goes in its `source` column so a reviewer can weight it.

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
