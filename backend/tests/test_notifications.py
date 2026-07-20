"""In-app notifications: device-token registration/upsert, listing/pagination,
mark-read, cooldown/dedup, and cross-company isolation."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.device_token import DeviceToken
from app.models.enums import Role
from app.models.notification import Notification
from app.models.user import User
from app.services.notification_service import NotificationService
from tests.factories import auth_header, make_company, make_notification, make_user

pytestmark = pytest.mark.integration


@pytest.fixture
def company(db):
    c = make_company(db, name="Notifyco", slug="notifyco")
    make_user(db, company=c, email="owner@notifyco.com", role=Role.COMPANY_OWNER)
    make_user(db, company=c, email="emp@notifyco.com", role=Role.EMPLOYEE)
    make_user(db, company=c, email="emp2@notifyco.com", role=Role.EMPLOYEE)
    return c


def _user(db, company, email: str) -> User:
    return db.query(User).filter_by(company_id=company.id, email=email).one()


def test_register_device_token(client, company, db):
    db.commit()
    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.post(
        "/api/v1/notifications/device-tokens",
        headers=headers,
        json={"platform": "android", "token": "device-token-abc"},
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]
    assert data["platform"] == "android"
    assert "id" in data
    assert "last_seen_at" in data


def test_reregistering_same_token_upserts_without_duplicating(client, company, db):
    emp = _user(db, company, "emp@notifyco.com")
    db.commit()
    headers = auth_header(client, email="emp@notifyco.com", password="password123")

    first = client.post(
        "/api/v1/notifications/device-tokens",
        headers=headers,
        json={"platform": "android", "token": "same-token"},
    )
    assert first.status_code == 201, first.text
    first_id = first.json()["data"]["id"]
    first_last_seen = first.json()["data"]["last_seen_at"]

    # Re-register the identical token, this time reporting iOS (e.g. reinstall).
    second = client.post(
        "/api/v1/notifications/device-tokens",
        headers=headers,
        json={"platform": "ios", "token": "same-token"},
    )
    assert second.status_code == 201, second.text
    second_data = second.json()["data"]
    assert second_data["id"] == first_id
    assert second_data["platform"] == "ios"

    rows = db.query(DeviceToken).filter_by(user_id=emp.id, token="same-token").all()
    assert len(rows) == 1
    assert rows[0].platform.value == "ios"
    assert rows[0].last_seen_at is not None
    # last_seen_at was refreshed (upsert in place, not a new row).
    assert first_last_seen is not None


def test_list_notifications_scoped_to_caller_only(client, company, db):
    emp = _user(db, company, "emp@notifyco.com")
    other = _user(db, company, "emp2@notifyco.com")
    make_notification(db, company=company, user=emp, type="task.assigned", title="Mine 1")
    make_notification(db, company=company, user=emp, type="task.assigned", title="Mine 2", entity_id=None)
    make_notification(db, company=company, user=other, type="task.assigned", title="Not mine")
    db.commit()

    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.get("/api/v1/notifications", headers=headers)
    assert resp.status_code == 200, resp.text
    titles = {n["title"] for n in resp.json()["data"]}
    assert titles == {"Mine 1", "Mine 2"}


def test_list_notifications_unread_only_filter(client, company, db):
    emp = _user(db, company, "emp@notifyco.com")
    make_notification(db, company=company, user=emp, type="task.assigned", title="Unread")
    make_notification(
        db, company=company, user=emp, type="task.assigned", title="Read",
        read_at=datetime.now(timezone.utc),
    )
    db.commit()

    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.get("/api/v1/notifications", headers=headers, params={"unread_only": "true"})
    assert resp.status_code == 200, resp.text
    titles = {n["title"] for n in resp.json()["data"]}
    assert titles == {"Unread"}

    resp_all = client.get("/api/v1/notifications", headers=headers)
    assert {n["title"] for n in resp_all.json()["data"]} == {"Unread", "Read"}


def test_list_notifications_pagination_meta(client, company, db):
    emp = _user(db, company, "emp@notifyco.com")
    for i in range(5):
        make_notification(db, company=company, user=emp, type="task.assigned", title=f"N{i}")
    db.commit()

    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.get(
        "/api/v1/notifications", headers=headers, params={"page": 1, "page_size": 2}
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert len(body["data"]) == 2
    meta = body["meta"]
    assert meta["total"] == 5
    assert meta["page"] == 1
    assert meta["page_size"] == 2
    assert meta["total_pages"] == 3

    resp_page2 = client.get(
        "/api/v1/notifications", headers=headers, params={"page": 2, "page_size": 2}
    )
    assert len(resp_page2.json()["data"]) == 2


def test_mark_read_sets_read_at(client, company, db):
    emp = _user(db, company, "emp@notifyco.com")
    notification = make_notification(db, company=company, user=emp, type="task.assigned", title="Mark me")
    db.commit()

    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.post(f"/api/v1/notifications/{notification.id}/read", headers=headers)
    assert resp.status_code == 200, resp.text
    assert resp.json()["data"]["read_at"] is not None


def test_mark_read_404_for_another_users_notification(client, company, db):
    other = _user(db, company, "emp2@notifyco.com")
    notification = make_notification(db, company=company, user=other, type="task.assigned", title="Not yours")
    db.commit()

    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.post(f"/api/v1/notifications/{notification.id}/read", headers=headers)
    assert resp.status_code == 404


def test_mark_read_404_for_nonexistent_id(client, company, db):
    db.commit()
    headers = auth_header(client, email="emp@notifyco.com", password="password123")
    resp = client.post(f"/api/v1/notifications/{uuid.uuid4()}/read", headers=headers)
    assert resp.status_code == 404


def test_create_and_dispatch_dedup_within_cooldown(company, db):
    emp = _user(db, company, "emp@notifyco.com")
    entity_id = uuid.uuid4()
    service = NotificationService(db)

    first = service.create_and_dispatch(
        company_id=company.id,
        user_id=emp.id,
        type="task.assigned",
        title="New task assigned",
        entity_id=entity_id,
    )
    assert first is not None

    second = service.create_and_dispatch(
        company_id=company.id,
        user_id=emp.id,
        type="task.assigned",
        title="New task assigned",
        entity_id=entity_id,
    )
    assert second is None

    rows = (
        db.query(Notification)
        .filter_by(user_id=emp.id, type="task.assigned", entity_id=entity_id)
        .all()
    )
    assert len(rows) == 1


def test_create_and_dispatch_allows_new_after_cooldown_expires(company, db):
    """Not part of the required coverage list, but cheaply confirms the
    cooldown window is time-bounded rather than a permanent dedup."""
    emp = _user(db, company, "emp@notifyco.com")
    entity_id = uuid.uuid4()
    make_notification(
        db,
        company=company,
        user=emp,
        type="task.assigned",
        title="Old one",
        entity_id=entity_id,
        created_at=datetime.now(timezone.utc) - timedelta(minutes=16),
    )
    db.commit()

    service = NotificationService(db)
    second = service.create_and_dispatch(
        company_id=company.id,
        user_id=emp.id,
        type="task.assigned",
        title="New task assigned",
        entity_id=entity_id,
    )
    assert second is not None

    rows = (
        db.query(Notification)
        .filter_by(user_id=emp.id, type="task.assigned", entity_id=entity_id)
        .all()
    )
    assert len(rows) == 2


def test_notifications_isolated_across_companies(client, db):
    acme = make_company(db, name="Acme7", slug="acme7")
    globex = make_company(db, name="Globex7", slug="globex7")
    make_user(db, company=acme, email="emp@acme7.com", role=Role.EMPLOYEE)
    globex_emp = make_user(db, company=globex, email="emp@globex7.com", role=Role.EMPLOYEE)
    make_notification(db, company=globex, user=globex_emp, type="task.assigned", title="Globex only")
    db.commit()

    headers = auth_header(client, email="emp@acme7.com", password="password123")
    resp = client.get("/api/v1/notifications", headers=headers)
    assert resp.status_code == 200, resp.text
    assert resp.json()["data"] == []
