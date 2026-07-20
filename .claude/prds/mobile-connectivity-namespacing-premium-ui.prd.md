# Mobile Connectivity, API Namespacing & Premium UI Pass

## Problem
The SCMS backend and Flutter mobile app are built, but the backend's default ports (8000, 5432, 6379, 9000/9001) and API prefix (`/api/v1`) are hardcoded without regard for other projects sharing the same host or infrastructure. This has already caused a port collision when running SCMS alongside another project, blocking local development and multi-environment testing. Separately, the mobile app's existing screens (auth, dashboard, issues, tasks, tracking, uploads, etc.) are functionally scaffolded but not yet held to a consistent, polished visual standard, and have not been verified across device sizes/orientations.

## Evidence
- Developer has already hit a real port conflict (one of SCMS's default docker-compose ports was already bound by another project on the same machine).
- `docker-compose.yml` binds `5432`, `6379`, `9000`, `9001`, and `8000` directly with no project-specific offset or namespacing.
- `BACKEND_CORS_ORIGINS` defaults to an empty list, and no documented CORS configuration exists per environment (local/staging/prod) — Assumption, needs validation via manual test from a real device/emulator against each environment.
- UI polish/responsiveness gap — Assumption, needs validation via a design/UX audit of existing screens against target devices.

## Users
- **Primary**: The developer (you), responsible for running SCMS alongside other local/shared projects and for shipping the mobile app to real devices across local, staging, and production environments.
- **Not for**: End-field-users of the mobile app are downstream beneficiaries of the UI work, but are not the ones raising this request — this PRD is scoped to developer/operator-facing connectivity and engineering-driven UI quality, not a field-user-requested feature.

## Hypothesis
We believe **giving SCMS unique, configurable ports/prefixes and correct per-environment CORS settings, plus a premium and fully responsive UI pass across all existing mobile screens**, will **eliminate infrastructure collisions with other projects and remove connectivity/visual quality as blockers to real-device and multi-environment testing**.
We'll know we're right when the backend can run alongside at least one other project on the same host with zero port/route collisions, the mobile app connects successfully from a real device/emulator in local, staging, and production configurations without CORS errors, and every existing screen renders correctly (no overflow/clipping) across representative phone/tablet sizes in both orientations.

## Success Metrics
| Metric | Target | How measured |
|---|---|---|
| Port/route collisions when co-located with another project | 0 | Run SCMS's docker-compose alongside a second sample project; confirm all services bind and both APIs respond on distinct ports/prefixes |
| Mobile-to-backend connectivity across environments | 100% success (local, staging, prod) | Manual connection test from a real device/emulator against each configured `API_BASE_URL`, confirm no CORS/network errors |
| Existing screens passing responsive/visual review | 100% of current screens (auth, dashboard, issues, tasks, tracking, uploads, notifications, profile, projects, team, progress_reports) | Manual/QA pass on each screen at phone + tablet breakpoints, portrait + landscape, against the updated design system |

## Scope
**MVP**
- Backend: make all exposed ports and the API route prefix configurable via environment variables, with SCMS-specific non-default values, so the stack can run alongside other projects without collision.
- Backend: correct, environment-aware CORS configuration (local/staging/prod) documented and verified against the mobile app.
- Mobile: full responsive + premium visual pass across all existing screens, built on an upgraded shared design system (theme tokens, spacing, type scale, motion) rather than a full app rewrite.

**Out of scope**
- New mobile features or screens — this pass touches only what already exists.
- Production deployment/infrastructure automation (CI/CD pipelines, TLS/certificate provisioning, domain registration) — this PRD makes the app *configuration-ready* for those environments, it does not stand up the environments themselves.

## Delivery Milestones
<!-- Business outcomes, not engineering tasks. /plan turns each into a plan. -->
<!-- Status: pending | in-progress | complete -->

| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Collision-free backend infrastructure | SCMS runs alongside other projects on shared infra with zero port or route collisions | complete | `.claude/plans/collision-free-backend-infrastructure.plan.md` |
| 2 | Verified mobile connectivity across environments | Mobile app connects to the backend without CORS/network errors in local, staging, and production configurations | in-progress (code complete; real-device + staging/prod verification pending — see Open Questions) | `.claude/plans/verified-mobile-connectivity-across-environments.plan.md` |
| 3 | Premium, fully responsive UI across existing screens | Every existing mobile screen matches the upgraded design system and renders correctly across phone/tablet sizes and orientations | in-progress (code complete; dart analyze/flutter test/goldens/device check pending — no Flutter toolchain in this environment) | `.claude/plans/premium-responsive-ui-pass.plan.md` |

## Open Questions
- [ ] What other project(s) does SCMS need to coexist with, and what ports/prefixes do they already use? (needed to choose non-colliding defaults)
- [ ] Are staging and production environments already provisioned (with known hostnames/domains), or are those environments still TBD?
- [ ] Is there an existing brand/design reference (colors, logo, typography) the "premium" visual direction should align to, or is this open-ended?
- [ ] Should the API route prefix change (e.g. from `/api/v1` to something SCMS-specific like `/scms/api/v1`) count as a breaking change for any already-integrated client, or is the mobile app the only consumer today?

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Changing default ports/prefix breaks existing local dev setups or scripts that hardcode current values | Medium | Medium | Grep the repo (backend, mobile, docker-compose, CI) for hardcoded ports/prefixes before changing defaults; update all references together |
| Overly permissive CORS (e.g. wildcard origins) introduced to "make it work everywhere" | Medium | High | Explicitly enumerate allowed origins per environment; never use `*` in staging/production |
| "Premium UI" is subjective without a design reference, leading to rework | Medium | Medium | Resolve the open question on design/brand reference before implementation planning begins |
| Full-screen UI pass scope creep into new features | Low | Medium | Enforce out-of-scope boundary (no new screens/features) during `/plan` breakdown |

---
*Status: DRAFT — requirements only. Implementation planning pending via /plan.*
