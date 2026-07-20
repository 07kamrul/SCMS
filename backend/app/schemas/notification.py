"""Notification and device-token schemas."""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import DevicePlatform


class NotificationPublic(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str | None
    data: dict | None
    entity_id: uuid.UUID | None
    read_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class DeviceTokenRegister(BaseModel):
    platform: DevicePlatform
    token: str = Field(min_length=1, max_length=500)


class DeviceTokenPublic(BaseModel):
    id: uuid.UUID
    platform: DevicePlatform
    last_seen_at: datetime

    model_config = {"from_attributes": True}
