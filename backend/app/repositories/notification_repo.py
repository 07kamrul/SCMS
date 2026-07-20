"""Notification data access, always tenant-scoped."""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import func, select

from app.models.notification import Notification
from app.repositories.base import BaseRepository


class NotificationRepository(BaseRepository[Notification]):
    model = Notification

    def find_recent_duplicate(
        self,
        *,
        user_id: uuid.UUID,
        type: str,
        entity_id: uuid.UUID | None,
        since: datetime,
    ) -> Notification | None:
        """Cooldown/dedup check: an existing notification of the same
        (user, type, entity) created within the cooldown window."""
        stmt = select(Notification).where(
            Notification.user_id == user_id,
            Notification.type == type,
            Notification.entity_id == entity_id,
            Notification.created_at >= since,
        )
        return self.db.execute(stmt).scalars().first()

    def list_for_user(
        self,
        *,
        company_id: uuid.UUID,
        user_id: uuid.UUID,
        unread_only: bool = False,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Notification], int]:
        base = select(Notification).where(
            Notification.company_id == company_id, Notification.user_id == user_id
        )
        if unread_only:
            base = base.where(Notification.read_at.is_(None))
        total = int(
            self.db.execute(select(func.count()).select_from(base.subquery())).scalar_one()
        )
        rows = list(
            self.db.execute(
                base.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
            ).scalars().all()
        )
        return rows, total
