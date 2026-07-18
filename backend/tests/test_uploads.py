"""Presigned photo-upload endpoint used by the mobile client."""
from __future__ import annotations

import pytest

from app.models.enums import Role
from tests.factories import auth_header, make_company, make_user

pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def _fake_s3(monkeypatch):
    """Avoid any real network call to MinIO/S3 during tests."""

    class _FakeS3Client:
        def generate_presigned_url(self, _operation, *, Params, ExpiresIn):
            return f"https://fake-minio.test/{Params['Bucket']}/{Params['Key']}?sig=fake&expires={ExpiresIn}"

    monkeypatch.setattr("app.utils.storage._s3_client", lambda: _FakeS3Client())


@pytest.fixture
def company(db):
    c = make_company(db, name="Uploadco", slug="uploadco")
    make_user(db, company=c, email="employee@uploadco.com", role=Role.EMPLOYEE)
    return c


def test_presign_returns_upload_and_photo_urls(client, company):
    headers = auth_header(client, email="employee@uploadco.com", password="password123")
    resp = client.post(
        "/api/v1/uploads/presign",
        json={"entity_type": "task", "content_type": "image/jpeg"},
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["success"] is True
    data = body["data"]
    assert data["upload_url"].startswith("https://fake-minio.test/")
    assert data["key"].startswith(f"task/{company.id}/")
    assert data["key"].endswith(".jpg")
    assert data["photo_url"] == f"http://localhost:9000/scfms-media/{data['key']}"
    assert data["expires_in"] == 300


def test_presign_requires_authentication(client):
    resp = client.post(
        "/api/v1/uploads/presign",
        json={"entity_type": "task", "content_type": "image/jpeg"},
    )
    assert resp.status_code == 401, resp.text
    assert resp.json()["success"] is False
