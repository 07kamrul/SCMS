"""Role-tailored dashboard summary: shape per role, count correctness against
seeded data, and an end-to-end task-creation -> notification -> dashboard check.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.models.enums import AssignmentRole, LocationStatus, Role, TaskStatus
from app.models.user import User
from tests.factories import (
    auth_header,
    make_assignment,
    make_company,
    make_issue,
    make_notification,
    make_project,
    make_task,
    make_user,
)

pytestmark = pytest.mark.integration

_ALL_LOCATION_STATUS_VALUES = {s.value for s in LocationStatus}
assert len(_ALL_LOCATION_STATUS_VALUES) == 10


@pytest.fixture
def company(db):
    c = make_company(db, name="Dashco", slug="dashco")
    make_user(db, company=c, email="owner@dashco.com", role=Role.COMPANY_OWNER)
    make_user(db, company=c, email="hr@dashco.com", role=Role.HR_ADMIN)
    make_user(db, company=c, email="pe@dashco.com", role=Role.PROJECT_ENGINEER)
    make_user(db, company=c, email="se@dashco.com", role=Role.SITE_ENGINEER)
    make_user(db, company=c, email="emp@dashco.com", role=Role.EMPLOYEE)
    return c


def _user(db, company, email: str) -> User:
    return db.query(User).filter_by(company_id=company.id, email=email).one()


ROLE_EMAILS = {
    Role.COMPANY_OWNER: "owner@dashco.com",
    Role.HR_ADMIN: "hr@dashco.com",
    Role.PROJECT_ENGINEER: "pe@dashco.com",
    Role.SITE_ENGINEER: "se@dashco.com",
    Role.EMPLOYEE: "emp@dashco.com",
}

# (role, pending_task_approvals is non-null, team_status_counts is non-null)
_SHAPE_EXPECTATIONS = [
    (Role.COMPANY_OWNER, True, True),
    (Role.HR_ADMIN, False, True),
    (Role.PROJECT_ENGINEER, True, True),
    (Role.SITE_ENGINEER, False, True),
    (Role.EMPLOYEE, False, False),
]


@pytest.mark.parametrize("role,pending_non_null,team_non_null", _SHAPE_EXPECTATIONS)
def test_dashboard_shape_per_role(client, company, db, role, pending_non_null, team_non_null):
    db.commit()
    headers = auth_header(client, email=ROLE_EMAILS[role], password="password123")
    resp = client.get("/api/v1/dashboard/me", headers=headers)
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["role"] == role.value
    for key in (
        "my_open_tasks",
        "my_overdue_tasks",
        "my_open_issues",
        "visible_project_count",
        "unread_notifications",
    ):
        assert isinstance(data[key], int)

    if pending_non_null:
        assert isinstance(data["pending_task_approvals"], int)
    else:
        assert data["pending_task_approvals"] is None

    if team_non_null:
        assert isinstance(data["team_status_counts"], dict)
        counts = data["team_status_counts"]
        assert set(counts.keys()) == _ALL_LOCATION_STATUS_VALUES
        if role == Role.COMPANY_OWNER:
            # Owner sees every active user in the company (all 5 seeded
            # users), none of whom have ever submitted a location point ->
            # all fall into UNKNOWN, everything else zero-filled.
            assert counts[LocationStatus.UNKNOWN.value] == 5
            assert sum(v for k, v in counts.items() if k != LocationStatus.UNKNOWN.value) == 0
        else:
            # No assignments seeded for HR/PE/SE in this fixture -> their
            # tracking scope (assigned teammates) is empty, so every status
            # is zero-filled.
            assert all(v == 0 for v in counts.values())
    else:
        assert data["team_status_counts"] is None


def test_dashboard_counts_reflect_seeded_tasks_and_issues(client, company, db):
    project = make_project(db, company=company, name="Site A")
    other_project = make_project(db, company=company, name="Site B")
    emp = _user(db, company, "emp@dashco.com")
    make_assignment(db, company=company, project=project, user=emp, role=AssignmentRole.EMPLOYEE)

    past = datetime.now(timezone.utc) - timedelta(days=1)
    # 2 tasks assigned to emp: one overdue+open, one completed (not overdue).
    make_task(db, company=company, project=project, title="Overdue task", assigned_to=emp, due_date=past)
    make_task(
        db, company=company, project=project, title="Done task", assigned_to=emp,
        due_date=past, status=TaskStatus.COMPLETED,
    )
    # A task assigned to someone else must not count toward emp's numbers.
    make_task(db, company=company, project=other_project, title="Not emp's task")

    # 2 issues touching emp (one reported, one assigned), 1 unrelated issue.
    make_issue(db, company=company, project=project, title="Reported by emp", reported_by=emp)
    make_issue(db, company=company, project=project, title="Assigned to emp", assigned_to=emp)
    make_issue(db, company=company, project=other_project, title="Unrelated issue")

    # An unread + a read notification for emp.
    make_notification(db, company=company, user=emp, type="task.assigned", title="Unread one")
    make_notification(
        db, company=company, user=emp, type="task.assigned", title="Already read",
        read_at=datetime.now(timezone.utc),
    )
    db.commit()

    headers = auth_header(client, email="emp@dashco.com", password="password123")
    resp = client.get("/api/v1/dashboard/me", headers=headers)
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]

    assert data["my_open_tasks"] == 2  # both tasks assigned to emp, regardless of status
    assert data["my_overdue_tasks"] == 1  # only the non-terminal overdue one
    assert data["my_open_issues"] == 2  # reported-by-emp + assigned-to-emp
    assert data["visible_project_count"] == 1  # only the project emp is assigned to
    assert data["unread_notifications"] == 1


def test_owner_visible_project_count_is_company_wide(client, company, db):
    make_project(db, company=company, name="Site A")
    make_project(db, company=company, name="Site B")
    db.commit()
    headers = auth_header(client, email="owner@dashco.com", password="password123")
    resp = client.get("/api/v1/dashboard/me", headers=headers)
    assert resp.json()["data"]["visible_project_count"] == 2


def test_pe_pending_approvals_scoped_to_own_projects(client, company, db):
    """A Project Engineer holds TASK_CREATE but only PROJECT_VIEW_ASSIGNED --
    they must not see `pending_task_approvals` for projects they aren't
    assigned to, matching GET /tasks' own project scoping.
    """
    own_project = make_project(db, company=company, name="PE's own site")
    other_project = make_project(db, company=company, name="A site PE cannot see")
    pe = _user(db, company, "pe@dashco.com")
    make_assignment(db, company=company, project=own_project, user=pe, role=AssignmentRole.PROJECT_ENGINEER)

    # No submitted task in PE's own project...
    make_task(db, company=company, project=own_project, title="Todo in own project")
    # ...but one exists in a project the PE is not assigned to.
    make_task(
        db, company=company, project=other_project, title="Submitted elsewhere",
        status=TaskStatus.SUBMITTED,
    )
    db.commit()

    # Sanity check: PE genuinely cannot see the other project's task via the
    # regular tasks endpoint (proves the project really is out of scope).
    headers = auth_header(client, email="pe@dashco.com", password="password123")
    tasks_resp = client.get("/api/v1/tasks", headers=headers)
    assert tasks_resp.status_code == 200
    assert "Submitted elsewhere" not in {t["title"] for t in tasks_resp.json()["data"]}

    dash_resp = client.get("/api/v1/dashboard/me", headers=headers)
    assert dash_resp.status_code == 200, dash_resp.text
    assert dash_resp.json()["data"]["pending_task_approvals"] == 0


def test_end_to_end_task_creation_notifies_assignee_and_updates_dashboard(client, company, db):
    project = make_project(db, company=company, name="E2E site")
    pe = _user(db, company, "pe@dashco.com")
    emp = _user(db, company, "emp@dashco.com")
    make_assignment(db, company=company, project=project, user=pe, role=AssignmentRole.PROJECT_ENGINEER)
    make_assignment(db, company=company, project=project, user=emp, role=AssignmentRole.EMPLOYEE)
    db.commit()

    pe_headers = auth_header(client, email="pe@dashco.com", password="password123")
    emp_headers = auth_header(client, email="emp@dashco.com", password="password123")

    baseline = client.get("/api/v1/dashboard/me", headers=emp_headers).json()["data"]
    assert baseline["unread_notifications"] == 0

    create_resp = client.post(
        "/api/v1/tasks",
        headers=pe_headers,
        json={
            "project_id": str(project.id),
            "title": "New task for emp",
            "assigned_to_user_id": str(emp.id),
        },
    )
    assert create_resp.status_code == 201, create_resp.text

    notifications_resp = client.get("/api/v1/notifications", headers=emp_headers)
    assert notifications_resp.status_code == 200
    notif_data = notifications_resp.json()["data"]
    assert any(n["type"] == "task.assigned" for n in notif_data)

    updated = client.get("/api/v1/dashboard/me", headers=emp_headers).json()["data"]
    assert updated["unread_notifications"] == baseline["unread_notifications"] + 1
    assert updated["my_open_tasks"] == baseline["my_open_tasks"] + 1


def test_dashboard_isolated_across_companies(client, db):
    acme = make_company(db, name="Acme8", slug="acme8")
    globex = make_company(db, name="Globex8", slug="globex8")
    make_user(db, company=acme, email="emp@acme8.com", role=Role.EMPLOYEE)
    globex_emp = make_user(db, company=globex, email="emp@globex8.com", role=Role.EMPLOYEE)
    globex_project = make_project(db, company=globex, name="Globex project")
    make_assignment(db, company=globex, project=globex_project, user=globex_emp)
    make_notification(db, company=globex, user=globex_emp, type="task.assigned", title="Globex")
    db.commit()

    headers = auth_header(client, email="emp@acme8.com", password="password123")
    resp = client.get("/api/v1/dashboard/me", headers=headers)
    assert resp.status_code == 200, resp.text
    data = resp.json()["data"]
    assert data["visible_project_count"] == 0
    assert data["unread_notifications"] == 0
