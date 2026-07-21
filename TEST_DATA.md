# Test Data & Testing Guide

Test users, seeded demo data, and step-by-step instructions for manually
testing SCMS (all 5 roles) via the API docs UI or `curl`.

## 1. One-time setup

```bash
cd /root/opt/SCMS
cp .env.example .env                       # first time only
cp backend/.env.example backend/.env       # first time only; set a real JWT_SECRET_KEY
docker compose up -d                       # starts db, redis, minio, backend
docker compose exec backend python seed.py # creates the demo company + users below
```

`seed.py` is idempotent — re-run it any time to reset passwords or restore
rows if you deleted them.

- Swagger UI: http://localhost:18000/docs
- Health check: http://localhost:18000/api/v1/health
- MinIO console: http://localhost:19001

## 2. Test users (all 5 roles)

Company: **Demo Construction Co.** (slug `demo-construction`)

| Role | Full name | Email | Phone | Password |
|---|---|---|---|---|
| Company Owner | Olivia Owner | owner@demo.com | +8801711000001 | owner123 |
| HR Admin | Hina HR | hr@demo.com | +8801711000002 | hr123456 |
| Project Engineer | Peter PE | pe@demo.com | +8801711000003 | pe123456 |
| Site Engineer | Sara SE | se@demo.com | +8801711000004 | se123456 |
| Employee | Emil Employee | emp@demo.com | +8801711000005 | emp12345 |

You can log in with either `email` or `phone` (not both) — see the login
request shape below.

## 3. What's already seeded

- **3 projects**: Riverside Tower (running, 45%, has a GIS boundary),
  Greenfield Warehouse (planned, 0%), Lakeview Villas — Phase 1 (completed, 100%).
- **Assignments**: pe@demo.com and se@demo.com → Riverside Tower;
  emp@demo.com → Greenfield Warehouse.
- **Live locations**: se@demo.com is placed inside the Riverside Tower
  boundary (`inside_assigned`); pe@demo.com is ~45m outside it
  (`near_assigned`); emp@demo.com has no location point (`unknown`) —
  useful for testing the geofence status logic.
- **Tasks**: foundation slab (in progress, se), structural drawings
  (submitted, pe), site survey (todo, emp).
- **Issues**: rebar delivery delayed (high, reported by se), access road
  blocked by flooding (critical, reported by emp).
- **Daily progress report** on Riverside Tower for today, submitted by se,
  with 2 stage entries (Foundation 100%, Framing 20%) and 1 photo.

## 4. Role → what to test

Permission matrix lives in `backend/app/permissions/roles.py`.

| Role | Can do | Try this |
|---|---|---|
| **Company Owner** | Everything (all permissions) | View/manage company settings, create users, create/archive projects, view all tracking & reports |
| **HR Admin** | Manage users, view all projects/assignments, view tracking of assigned people, view reports | Create a new user, deactivate a user, reset a password, view assignments |
| **Project Engineer** | View/manage assigned projects, create/approve tasks, create/update issues, view progress & reports | Approve the "Submit structural drawings" task, create a new task on Riverside Tower |
| **Site Engineer** | View assigned projects, create/update tasks & issues, submit progress reports | Submit a new daily progress report, update the "Pour foundation slab" task status |
| **Employee** | View own assigned project, share location, view/update own tasks, create issues, upload photos | Update "Site survey" task status, report a new issue, upload a progress photo |

## 5. Manual test flow (Swagger UI)

1. Open http://localhost:18000/docs
2. `POST /api/v1/auth/login` → click "Try it out" → body:
   ```json
   { "email": "owner@demo.com", "password": "owner123" }
   ```
3. Copy `data.tokens.access_token` from the response.
4. Click the **Authorize** button (top right) → paste the token as
   `Bearer <access_token>` → Authorize.
5. Exercise endpoints for that role (e.g. `GET /api/v1/projects`,
   `GET /api/v1/dashboard/company` for owner/HR, `POST /api/v1/tasks` etc.).
6. Repeat from step 2 with a different demo user to test role restrictions —
   endpoints outside a role's permission set should return `403`.
7. Cross-tenant isolation: any resource ID from another company should
   return `404`, never `403` (avoids leaking existence).

## 6. Manual test flow (curl)

Login and grab a token in one step:

```bash
TOKEN=$(curl -s -X POST http://localhost:18000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"se@demo.com","password":"se123456"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['tokens']['access_token'])")

curl -s http://localhost:18000/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Other useful auth endpoints:

```bash
# refresh
curl -s -X POST http://localhost:18000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'

# logout (revokes one refresh token)
curl -s -X POST http://localhost:18000/api/v1/auth/logout \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"<refresh_token>"}'

# change password (requires bearer token)
curl -s -X POST http://localhost:18000/api/v1/auth/change-password \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"current_password":"se123456","new_password":"newpass123"}'
```

## 7. Edge cases worth testing

- **Login lockout**: submit a wrong password 5+ times for one user — the
  account should temporarily lock (see `backend/tests/` for the exact
  threshold), then confirm the correct password still fails until the
  lockout window passes.
- **Refresh rotation/reuse detection**: use a refresh token once (works),
  then reuse the same (now-rotated-out) token again — it should be rejected
  and, per the security design, ideally revoke the whole token family.
- **Multi-tenant isolation**: if you create a second company/user, confirm
  neither company's users/projects/tasks are visible to the other.
- **Geofence statuses**: check `GET /api/v1/locations` (or the dashboard) for
  se@demo.com (`inside_assigned`), pe@demo.com (`near_assigned`), and
  emp@demo.com (`unknown`, no point yet) — then POST a location for
  emp@demo.com and re-check the status changes.
- **RBAC 403s**: call an owner-only endpoint (e.g. company settings update)
  as emp@demo.com and confirm `403`, not `500` or silent success.

## 8. Automated tests

Automated tests use the **same PostgreSQL server/container** started by
`docker compose up -d` above — there's no second database service to run.
They connect to a separate *database name* (`scfms_test`) on that same
server, since the test suite drops and recreates the whole schema each run
(`Base.metadata.drop_all`/`create_all` in `backend/tests/conftest.py`) — that
reset must not run against the `scfms` database holding your seeded demo
data.

```bash
cd backend
createdb scfms_test 2>/dev/null || true
export TEST_DATABASE_URL="postgresql+psycopg://scfms:scfms_dev_password@localhost:15432/scfms_test"
pytest
```

Covers login/refresh-rotation/lockout, multi-tenant isolation, and the RBAC
permission matrix — a good reference for exact expected status codes if
manual testing gives an unexpected result.

## 9. Resetting test data

```bash
docker compose exec backend python seed.py   # safe re-run: resets passwords, adds any missing rows
```

To wipe everything and start clean:

```bash
docker compose down -v   # WARNING: deletes the Postgres/MinIO/Redis volumes
docker compose up -d
docker compose exec backend python seed.py
```
