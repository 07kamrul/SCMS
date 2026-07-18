"""Presigned photo-upload request/response schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field

from app.utils.storage import UploadEntityType

_EXT_BY_CONTENT_TYPE = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/heic": "heic",
}


class UploadPresignRequest(BaseModel):
    entity_type: UploadEntityType
    content_type: str = Field(min_length=1, max_length=100)

    @property
    def extension(self) -> str:
        return _EXT_BY_CONTENT_TYPE.get(self.content_type.lower(), "jpg")


class UploadPresignResponse(BaseModel):
    upload_url: str
    photo_url: str
    key: str
    expires_in: int
