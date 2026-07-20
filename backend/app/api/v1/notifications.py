"""In-app notifications: list mine, mark read, register a push device token."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.exceptions import NotFoundError
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import Envelope, PaginationParams, ok
from app.schemas.notification import DeviceTokenPublic, DeviceTokenRegister, NotificationPublic
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=Envelope[list[NotificationPublic]])
def list_my_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    unread_only: bool = Query(default=False),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> Envelope[list[NotificationPublic]]:
    pagination = PaginationParams(page=page, page_size=page_size)
    rows, total = NotificationService(db).list_for_user(
        company_id=current_user.company_id,
        user_id=current_user.id,
        unread_only=unread_only,
        offset=pagination.offset,
        limit=pagination.page_size,
    )
    return ok(
        [NotificationPublic.model_validate(r) for r in rows], meta=pagination.to_meta(total)
    )


@router.post("/{notification_id}/read", response_model=Envelope[NotificationPublic])
def mark_notification_read(
    notification_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Envelope[NotificationPublic]:
    notification = NotificationService(db).mark_read(
        company_id=current_user.company_id, user_id=current_user.id, notification_id=notification_id
    )
    if notification is None:
        raise NotFoundError("Notification not found.")
    return ok(NotificationPublic.model_validate(notification))


@router.post("/device-tokens", response_model=Envelope[DeviceTokenPublic], status_code=201)
def register_device_token(
    payload: DeviceTokenRegister,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Envelope[DeviceTokenPublic]:
    device_token = NotificationService(db).register_device_token(
        company_id=current_user.company_id,
        user_id=current_user.id,
        platform=payload.platform,
        token=payload.token,
    )
    return ok(DeviceTokenPublic.model_validate(device_token))
