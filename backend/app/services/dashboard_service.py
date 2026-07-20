"""Role-tailored 'what needs my attention today' summary.

Deliberately thin: every number here is a count already reachable through an
existing repository query (task/issue/project/notification), just composed
per-role. No new aggregation engine.
"""
from __future__ import annotations

import uuid
from collections import Counter

from sqlalchemy.orm import Session

from app.models.enums import LocationStatus, TaskStatus
from app.models.user import User
from app.permissions.roles import Permission, has_permission
from app.repositories.assignment_repo import AssignmentRepository
from app.repositories.issue_repo import IssueRepository
from app.repositories.notification_repo import NotificationRepository
from app.repositories.project_repo import ProjectRepository
from app.repositories.task_repo import TaskRepository
from app.schemas.common import PaginationParams
from app.schemas.dashboard import DashboardSummary
from app.services.location_service import LocationService

_COUNT_ONLY = PaginationParams(page=1, page_size=1)
_TEAM_VIEW_PERMISSIONS = (Permission.TRACKING_VIEW_ALL, Permission.TRACKING_VIEW_ASSIGNED)


class DashboardService:
    def __init__(self, db: Session):
        self.db = db
        self.tasks = TaskRepository(db)
        self.issues = IssueRepository(db)
        self.projects = ProjectRepository(db)
        self.assignments = AssignmentRepository(db)
        self.notifications = NotificationRepository(db)
        self.locations = LocationService(db)

    def summary_for(self, *, company_id: uuid.UUID, user: User) -> DashboardSummary:
        can_view_all_projects = has_permission(user.role, Permission.PROJECT_VIEW_ALL)
        can_approve_tasks = has_permission(user.role, Permission.TASK_APPROVE)
        can_view_team = any(has_permission(user.role, p) for p in _TEAM_VIEW_PERMISSIONS)

        project_ids = (
            None if can_view_all_projects
            else self.assignments.active_project_ids_for_user(company_id=company_id, user_id=user.id)
        )

        _, my_open_tasks = self.tasks.list_for_company(
            company_id=company_id,
            assigned_to_user_id=user.id,
            offset=_COUNT_ONLY.offset,
            limit=_COUNT_ONLY.page_size,
        )
        _, my_overdue_tasks = self.tasks.list_for_company(
            company_id=company_id,
            assigned_to_user_id=user.id,
            overdue_only=True,
            offset=_COUNT_ONLY.offset,
            limit=_COUNT_ONLY.page_size,
        )
        _, my_open_issues = self.issues.list_for_company(
            company_id=company_id,
            mine_user_id=user.id,
            offset=_COUNT_ONLY.offset,
            limit=_COUNT_ONLY.page_size,
        )
        visible_project_count = (
            self.projects.count_for_company(company_id)
            if can_view_all_projects
            else len(project_ids or set())
        )
        _, unread_notifications = self.notifications.list_for_user(
            company_id=company_id, user_id=user.id, unread_only=True,
            offset=_COUNT_ONLY.offset, limit=_COUNT_ONLY.page_size,
        )

        pending_task_approvals = None
        if can_approve_tasks:
            _, pending_task_approvals = self.tasks.list_for_company(
                company_id=company_id,
                project_ids=project_ids,
                status=TaskStatus.SUBMITTED,
                offset=_COUNT_ONLY.offset,
                limit=_COUNT_ONLY.page_size,
            )

        team_status_counts = None
        if can_view_team:
            rows = self.locations.team_status(
                company_id=company_id,
                current_user_id=user.id,
                can_view_all_tracking=has_permission(user.role, Permission.TRACKING_VIEW_ALL),
                can_view_all_projects=can_view_all_projects,
            )
            counts = Counter(status.value for _, status, _ in rows)
            team_status_counts = {status.value: counts.get(status.value, 0) for status in LocationStatus}

        return DashboardSummary(
            role=user.role,
            my_open_tasks=my_open_tasks,
            my_overdue_tasks=my_overdue_tasks,
            my_open_issues=my_open_issues,
            visible_project_count=visible_project_count,
            unread_notifications=unread_notifications,
            pending_task_approvals=pending_task_approvals,
            team_status_counts=team_status_counts,
        )
