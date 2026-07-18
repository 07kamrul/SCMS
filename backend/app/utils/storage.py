"""MinIO/S3 presigned-upload helpers.

Photos are stored as plain URL references on tasks/issues/progress-reports
(see their photo schemas) — the client uploads the file bytes directly to
object storage using a short-lived presigned PUT URL obtained here, then
posts the resulting public URL to the existing photo endpoints. This keeps
S3 credentials server-side only; the mobile app never holds them.
"""
from __future__ import annotations

import uuid
from functools import lru_cache
from typing import Literal

import boto3
from botocore.client import Config

from app.core.config import settings

UploadEntityType = Literal["task", "issue", "progress"]

PRESIGN_EXPIRE_SECONDS = 300


@lru_cache
def _s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.S3_ENDPOINT_URL,
        aws_access_key_id=settings.S3_ACCESS_KEY,
        aws_secret_access_key=settings.S3_SECRET_KEY,
        region_name=settings.S3_REGION,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def build_upload_key(company_id: uuid.UUID, entity_type: UploadEntityType, extension: str) -> str:
    ext = extension.lstrip(".").lower() or "jpg"
    return f"{entity_type}/{company_id}/{uuid.uuid4()}.{ext}"


def presign_put_url(key: str, content_type: str) -> str:
    return _s3_client().generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.S3_BUCKET, "Key": key, "ContentType": content_type},
        ExpiresIn=PRESIGN_EXPIRE_SECONDS,
    )


def public_url_for(key: str) -> str:
    return f"{settings.S3_PUBLIC_URL}/{settings.S3_BUCKET}/{key}"
