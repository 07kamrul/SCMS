# Plan: Collision-Free Backend Infrastructure

**Source PRD**: `.claude/prds/mobile-connectivity-namespacing-premium-ui.prd.md`
**Selected Milestone**: 1 — Collision-free backend infrastructure
**Complexity**: Small

## Summary
`docker-compose.yml` currently binds host ports `5432`, `6379`, `9000`, `9001`, and `8000` as string literals with no variable substitution, and has no explicit Compose project name — both are exactly what caused the developer's already-observed port collision when running SCMS alongside another project. `API_V1_PREFIX` is already environment-configurable via `backend/app/core/config.py`, so no backend code change is needed there; this milestone is purely infrastructure/config.

## Patterns to Mirror
| Category | Source | Pattern |
|---|---|---|
| Config | `backend/app/core/config.py:33` | Settings values already flow from `.env` via `pydantic-settings` (`API_V1_PREFIX`, `BACKEND_CORS_ORIGINS`) — no new backend code needed, only `.env`/compose changes |
| Env docs | `backend/.env.example` | Grouped, commented sections per concern (App / Security / Database / Redis / Object storage), each var documented inline — new host-port vars should follow the same style |
| Compose defaults | `docker-compose.yml:4-6` | Existing `${VAR:-default}` substitution already used for container-internal env (`POSTGRES_USER`, etc.) — the same substitution syntax should extend to the host-side port mappings, which currently don't use it |

## Files to Change
| File | Action | Why |
|---|---|---|
| `docker-compose.yml` | UPDATE | Add top-level `name: scms` to pin the Compose project namespace (containers/network/volumes) regardless of directory name; parameterize all 5 host-side port mappings as `${SCMS_*_PORT:-<non-common-default>}` |
| `.env.example` (new, repo root) | CREATE | Document the new `SCMS_DB_PORT`, `SCMS_REDIS_PORT`, `SCMS_MINIO_PORT`, `SCMS_MINIO_CONSOLE_PORT`, `SCMS_BACKEND_PORT` vars Compose reads for host-port substitution |
| `backend/.env.example` | UPDATE | Add a short note cross-referencing the root `.env.example` host-port vars, and confirm `API_V1_PREFIX` as the override point if a shared reverse proxy needs a different path prefix |
| `README.md` | UPDATE | Update the four hardcoded `localhost:8000` / `localhost:9001` / `localhost:5432` references (lines ~41-68) to reflect the new default ports and mention the override vars |

## Tasks
### Task 1: Pin the Compose project name
- **Action**: Add `name: scms` as the first line of `docker-compose.yml`, above `services:`
- **Mirror**: N/A — new top-level Compose key, no existing pattern in this repo to mirror
- **Validate**: `docker compose config | head -5` shows `name: scms`

### Task 2: Parameterize host ports with non-colliding defaults
- **Action**: Change each service's host-side port to `${SCMS_<SERVICE>_PORT:-<default>}`, using defaults outside the common range other local stacks are likely to claim, e.g.:
  - db: `"${SCMS_DB_PORT:-15432}:5432"`
  - redis: `"${SCMS_REDIS_PORT:-16379}:6379"`
  - minio: `"${SCMS_MINIO_PORT:-19000}:9000"`, `"${SCMS_MINIO_CONSOLE_PORT:-19001}:9001"`
  - backend: `"${SCMS_BACKEND_PORT:-18000}:8000"`
  (Container-internal ports on the right-hand side stay unchanged — only the host-side binding moves.)
- **Mirror**: `docker-compose.yml:4-6` (`${POSTGRES_USER:-scfms}` substitution style)
- **Validate**: `docker compose up -d` then `docker compose ps` shows the new default host ports bound; re-run with `SCMS_BACKEND_PORT=28000 docker compose up -d` and confirm the backend answers on `28000` instead

### Task 3: Document the new vars in a root `.env.example`
- **Action**: Create `/.env.example` at repo root (sibling to `docker-compose.yml`) listing the 5 `SCMS_*_PORT` vars with their defaults and one line each on purpose; note real `.env` (gitignored) is what Compose actually reads for substitution
- **Mirror**: `backend/.env.example` header/comment style (banner comment, grouped vars, inline guidance)
- **Validate**: `cat .env.example` renders cleanly; confirm `.gitignore` already excludes root `.env` (add the entry if missing)

### Task 4: Update README references
- **Action**: Update the API docs / health / MinIO console URLs and the `TEST_DATABASE_URL` example in `README.md` to use the new default ports, and add one sentence noting ports are overridable per the root `.env.example`
- **Mirror**: Existing README section structure (unchanged headings, just updated values)
- **Validate**: Manual read-through; links resolve to the ports actually bound after Task 2

## Validation
```bash
docker compose config                     # confirms name + substituted ports
docker compose up -d && docker compose ps # confirms default ports bind
SCMS_BACKEND_PORT=28000 docker compose up -d backend && curl -sf http://localhost:28000/api/v1/health
git grep -n "gitignore" -- .env           # confirm root .env stays untracked
```

## Risks
| Risk | Likelihood | Mitigation |
|---|---|---|
| Existing local `.env` files or scripts hardcode the old ports (5432/6379/9000/8000) | Medium | Defaults only change for *new* setups; anyone with an existing root `.env` can keep old values by setting `SCMS_*_PORT` explicitly — call this out in `.env.example` |
| Compose `name:` key requires a Compose version that supports the top-level `name` field | Low | `docker compose version` check as a pre-step; virtually all current Compose v2 releases support it |
| Changing README port numbers gets out of sync if defaults change again later | Low | Keep README pointing at the env-var names, not just literal numbers, where practical |

## Acceptance
- [ ] All tasks complete
- [ ] Validation passes
- [ ] Patterns mirrored, not reinvented
