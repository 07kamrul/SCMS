"""In-app notifications with cooldown/dedup, plus a pluggable push stub.

send_push() is intentionally a no-op logger: there are no real FCM/APNs
credentials configured for this project. It's the integration point a later
milestone wires up to an actual push provider — callers here don't change.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.device_token import DeviceToken
from app.models.enums import DevicePlatform
from app.models.notification import Notification
from app.repositories.device_token_repo import DeviceTokenRepository
from app.repositories.notification_repo import NotificationRepository

logger = logging.getLogger("scfms.notifications")

_COOLDOWN = timedelta(minutes=15)


class NotificationService:
    def __init__(self, db: Session):
        self.db = db
        self.notifications = NotificationRepository(db)
        self.device_tokens = DeviceTokenRepository(db)

    def create_and_dispatch(
        self,
        *,
        company_id: uuid.UUID,
        user_id: uuid.UUID,
        type: str,
        title: str,
        body: str | None = None,
        data: dict | None = None,
        entity_id: uuid.UUID | None = None,
    ) -> Notification | None:
        """Returns None (and creates nothing) if an identical notification
        was already created within the cooldown window."""
        since = datetime.now(timezone.utc) - _COOLDOWN
        duplicate = self.notifications.find_recent_duplicate(
            user_id=user_id, type=type, entity_id=entity_id, since=since
        )
        if duplicate is not None:
            return None

        notification = Notification(
            company_id=company_id,
            user_id=user_id,
            type=type,
            title=title,
            body=body,
            data=data,
            entity_id=entity_id,
        )
        self.notifications.add(notification)
        self.db.commit()
        self.db.refresh(notification)
        self._send_push(user_id=user_id, notification=notification)
        return notification

    def register_device_token(
        self, *, company_id: uuid.UUID, user_id: uuid.UUID, platform: DevicePlatform, token: str
    ) -> DeviceToken:
        existing = self.device_tokens.get_for_user_and_token(user_id=user_id, token=token)
        now = datetime.now(timezone.utc)
        if existing is not None:
            existing.last_seen_at = now
            existing.platform = platform
            self.db.commit()
            self.db.refresh(existing)
            return existing
        device_token = DeviceToken(
            company_id=company_id, user_id=user_id, platform=platform, token=token, last_seen_at=now
        )
        self.device_tokens.add(device_token)
        self.db.commit()
        self.db.refresh(device_token)
        return device_token

    def list_for_user(
        self, *, company_id: uuid.UUID, user_id: uuid.UUID, unread_only: bool, offset: int, limit: int
    ) -> tuple[list[Notification], int]:
        return self.notifications.list_for_user(
            company_id=company_id, user_id=user_id, unread_only=unread_only, offset=offset, limit=limit
        )

    def mark_read(
        self, *, company_id: uuid.UUID, user_id: uuid.UUID, notification_id: uuid.UUID
    ) -> Notification | None:
        notification = self.notifications.get_for_company(notification_id, company_id)
        if notification is None or notification.user_id != user_id:
            return None
        notification.read_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def _send_push(self, *, user_id: uuid.UUID, notification: Notification) -> None:
        tokens = self.device_tokens.list_for_user(user_id=user_id)
        if not tokens:
            return
        logger.info(
            "Push stub: would deliver notification %s (%s) to %d device(s) for user %s",
            notification.id, notification.type, len(tokens), user_id,
        )
