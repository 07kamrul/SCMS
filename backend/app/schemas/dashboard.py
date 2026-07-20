"""Role-tailored dashboard summary — composed from existing repos, no new
aggregation logic beyond what each domain service already exposes."""
from __future__ import annotations

from pydantic import BaseModel

from app.models.enums import Role


class DashboardSummary(BaseModel):
    role: Role
    my_open_tasks: int
    my_overdue_tasks: int
    my_open_issues: int
    visible_project_count: int
    unread_notifications: int
    # Only populated for roles that hold TASK_APPROVE (Project Engineer).
    pending_task_approvals: int | None = None
    # Only populated for roles that can view team tracking (Owner/HR/PE/SE).
    team_status_counts: dict[str, int] | None = None
