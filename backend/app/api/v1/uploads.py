"""Presigned photo upload: mobile clients get a short-lived MinIO PUT URL,
upload the file directly, then POST the resulting photo_url to the existing
task/issue/progress-report photo endpoints. Keeps S3 credentials server-side."""
from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.deps import require_permission
from app.models.user import User
from app.permissions.roles import Permission
from app.schemas.common import Envelope, ok
from app.schemas.upload import UploadPresignRequest, UploadPresignResponse
from app.utils.storage import (
    PRESIGN_EXPIRE_SECONDS,
    build_upload_key,
    presign_put_url,
    public_url_for,
)

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/presign", response_model=Envelope[UploadPresignResponse], status_code=201)
def presign_upload(
    payload: UploadPresignRequest,
    current_user: User = Depends(require_permission(Permission.PHOTO_UPLOAD)),
) -> Envelope[UploadPresignResponse]:
    key = build_upload_key(current_user.company_id, payload.entity_type, payload.extension)
    return ok(
        UploadPresignResponse(
            upload_url=presign_put_url(key, payload.content_type),
            photo_url=public_url_for(key),
            key=key,
            expires_in=PRESIGN_EXPIRE_SECONDS,
        )
    )
