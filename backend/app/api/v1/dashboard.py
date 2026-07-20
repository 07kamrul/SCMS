"""Role-tailored dashboard: 'what needs my attention today'."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import Envelope, ok
from app.schemas.dashboard import DashboardSummary
from app.services.dashboard_service import DashboardService

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/me", response_model=Envelope[DashboardSummary])
def get_my_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Envelope[DashboardSummary]:
    summary = DashboardService(db).summary_for(company_id=current_user.company_id, user=current_user)
    return ok(summary)
