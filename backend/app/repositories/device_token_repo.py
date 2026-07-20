"""Device-token data access, always tenant-scoped."""
from __future__ import annotations

import uuid

from sqlalchemy import select

from app.models.device_token import DeviceToken
from app.repositories.base import BaseRepository


class DeviceTokenRepository(BaseRepository[DeviceToken]):
    model = DeviceToken

    def get_for_user_and_token(
        self, *, user_id: uuid.UUID, token: str
    ) -> DeviceToken | None:
        stmt = select(DeviceToken).where(
            DeviceToken.user_id == user_id, DeviceToken.token == token
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def list_for_user(self, *, user_id: uuid.UUID) -> list[DeviceToken]:
        stmt = select(DeviceToken).where(DeviceToken.user_id == user_id)
        return list(self.db.execute(stmt).scalars().all())
