from __future__ import annotations

from dataclasses import dataclass, field
from threading import Lock


@dataclass(slots=True)
class MetricsRegistry:
    request_total: int = 0
    error_total: int = 0
    task_created_total: int = 0
    task_promoted_total: int = 0
    _lock: Lock = field(default_factory=Lock)

    def increment(self, field_name: str, value: int = 1) -> None:
        with self._lock:
            current_value = getattr(self, field_name)
            setattr(self, field_name, current_value + value)

    def render(self) -> bytes:
        with self._lock:
            lines = [
                "# HELP sprintboard_requests_total Total HTTP requests handled by the app.",
                "# TYPE sprintboard_requests_total counter",
                f"sprintboard_requests_total {self.request_total}",
                "# HELP sprintboard_errors_total Total unhandled application errors.",
                "# TYPE sprintboard_errors_total counter",
                f"sprintboard_errors_total {self.error_total}",
                "# HELP sprintboard_task_created_total Total tasks created through the web UI.",
                "# TYPE sprintboard_task_created_total counter",
                f"sprintboard_task_created_total {self.task_created_total}",
                "# HELP sprintboard_task_promoted_total Total workflow promotions for tasks.",
                "# TYPE sprintboard_task_promoted_total counter",
                f"sprintboard_task_promoted_total {self.task_promoted_total}",
            ]
        return "\n".join(lines).encode("utf-8")

