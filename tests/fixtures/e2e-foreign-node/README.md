# widget-api

A tiny Express service that manages widget users. This is a **foreign / brownfield**
project fixture for the reverse-engineer end-to-end pipeline test: it has source
code, a manifest, a lockfile, and docs, but **no `docs/_architect_state.json`** — so
`bin/re-detect` classifies it as a foreign project to reverse-engineer.

## What it does

- `GET /health` — liveness + version.
- `GET /users` — list users (public projection).
- `POST /users` — create a user (validated against the `User` model's rules).

## Running

```bash
npm install
npm start   # listens on :3000 (override with PORT)
```

## Notes (intentionally stale)

This fixture is **deliberately behind current**: it pins `express@4.16.0` (a full
major behind the current stable) and declares `engines.node >=16 <17` (Node 16 is
past end-of-life). The reverse-engineer landscape-researcher cascade is expected to
flag both against live sources — do not "fix" them.
