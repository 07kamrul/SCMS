"""Aggregate v1 router. New feature routers get mounted here."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    assignments,
    auth,
    companies,
    dashboard,
    health,
    issues,
    locations,
    notifications,
    progress_reports,
    projects,
    tasks,
    uploads,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(companies.router)
api_router.include_router(users.router)
api_router.include_router(projects.router)
api_router.include_router(assignments.router)
api_router.include_router(locations.router)
api_router.include_router(tasks.router)
api_router.include_router(issues.router)
api_router.include_router(progress_reports.router)
api_router.include_router(uploads.router)
api_router.include_router(notifications.router)
api_router.include_router(dashboard.router)
