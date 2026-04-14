from __future__ import annotations

import json
import traceback
from pathlib import Path
from time import perf_counter
from urllib.parse import parse_qs

from .config import AppConfig
from .db import advance_task, create_task, initialize_database, list_tasks
from .metrics import MetricsRegistry
from .templates import render_dashboard


def _json_log(method: str, path: str, status: str, duration_ms: float) -> None:
    payload = {
        "method": method,
        "path": path,
        "status": status,
        "duration_ms": round(duration_ms, 2),
    }
    print(json.dumps(payload), flush=True)


def _read_static_file(path: Path) -> bytes:
    return path.read_bytes()


def create_app(config: AppConfig | None = None, metrics: MetricsRegistry | None = None):
    resolved_config = config or AppConfig.from_env()
    resolved_metrics = metrics or MetricsRegistry()
    initialize_database(resolved_config.database_path)
    static_dir = Path(__file__).parent / "static"

    def application(environ, start_response):
        request_started = perf_counter()
        resolved_metrics.increment("request_total")
        method = environ.get("REQUEST_METHOD", "GET").upper()
        path = environ.get("PATH_INFO", "/")

        try:
            if method == "GET" and path == "/":
                body = render_dashboard(resolved_config.app_name, list_tasks(resolved_config.database_path))
                headers = [("Content-Type", "text/html; charset=utf-8")]
                start_response("200 OK", headers)
                _json_log(method, path, "200", (perf_counter() - request_started) * 1000)
                return [body]

            if method == "POST" and path == "/tasks":
                request_body_size = int(environ.get("CONTENT_LENGTH") or "0")
                body = environ["wsgi.input"].read(request_body_size).decode("utf-8")
                form_data = parse_qs(body)
                title = form_data.get("title", [""])[0].strip()
                description = form_data.get("description", [""])[0].strip()

                if not title:
                    start_response("400 Bad Request", [("Content-Type", "text/plain; charset=utf-8")])
                    _json_log(method, path, "400", (perf_counter() - request_started) * 1000)
                    return [b"Title is required."]

                create_task(resolved_config.database_path, title, description)
                resolved_metrics.increment("task_created_total")
                start_response("303 See Other", [("Location", "/")])
                _json_log(method, path, "303", (perf_counter() - request_started) * 1000)
                return [b""]

            if method == "POST" and path.startswith("/tasks/") and path.endswith("/advance"):
                parts = [part for part in path.split("/") if part]
                task_id = int(parts[1])
                next_status = advance_task(resolved_config.database_path, task_id)
                if next_status is None:
                    start_response("404 Not Found", [("Content-Type", "text/plain; charset=utf-8")])
                    _json_log(method, path, "404", (perf_counter() - request_started) * 1000)
                    return [b"Task not found."]

                if next_status != "DONE":
                    resolved_metrics.increment("task_promoted_total")
                start_response("303 See Other", [("Location", "/")])
                _json_log(method, path, "303", (perf_counter() - request_started) * 1000)
                return [b""]

            if method == "GET" and path == "/healthz":
                start_response("200 OK", [("Content-Type", "application/json; charset=utf-8")])
                _json_log(method, path, "200", (perf_counter() - request_started) * 1000)
                return [b'{"status":"ok"}']

            if method == "GET" and path == "/metrics":
                start_response("200 OK", [("Content-Type", "text/plain; version=0.0.4; charset=utf-8")])
                _json_log(method, path, "200", (perf_counter() - request_started) * 1000)
                return [resolved_metrics.render()]

            if method == "GET" and path.startswith("/static/"):
                asset_path = (static_dir / path.removeprefix("/static/")).resolve()
                if asset_path.parent != static_dir.resolve():
                    start_response("403 Forbidden", [("Content-Type", "text/plain; charset=utf-8")])
                    _json_log(method, path, "403", (perf_counter() - request_started) * 1000)
                    return [b"Forbidden."]
                if not asset_path.exists():
                    start_response("404 Not Found", [("Content-Type", "text/plain; charset=utf-8")])
                    _json_log(method, path, "404", (perf_counter() - request_started) * 1000)
                    return [b"Not Found."]
                content_type = "text/css; charset=utf-8" if asset_path.suffix == ".css" else "text/plain"
                start_response("200 OK", [("Content-Type", content_type)])
                _json_log(method, path, "200", (perf_counter() - request_started) * 1000)
                return [_read_static_file(asset_path)]

            start_response("404 Not Found", [("Content-Type", "text/plain; charset=utf-8")])
            _json_log(method, path, "404", (perf_counter() - request_started) * 1000)
            return [b"Not Found."]
        except Exception:
            resolved_metrics.increment("error_total")
            traceback.print_exc()
            start_response("500 Internal Server Error", [("Content-Type", "text/plain; charset=utf-8")])
            _json_log(method, path, "500", (perf_counter() - request_started) * 1000)
            return [b"Internal Server Error."]

    return application

