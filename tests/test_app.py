from __future__ import annotations

import io
import shutil
import unittest
from pathlib import Path

from app import create_app
from app.config import AppConfig
from app.metrics import MetricsRegistry


def call_app(
    application, method: str, path: str, body: str = ""
) -> tuple[str, list[tuple[str, str]], bytes]:
    response = {}

    def start_response(status, headers):
        response["status"] = status
        response["headers"] = headers

    environ = {
        "REQUEST_METHOD": method,
        "PATH_INFO": path,
        "CONTENT_LENGTH": str(len(body.encode("utf-8"))),
        "CONTENT_TYPE": "application/x-www-form-urlencoded",
        "wsgi.input": io.BytesIO(body.encode("utf-8")),
    }
    payload = b"".join(application(environ, start_response))
    return response["status"], response["headers"], payload


class AppTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.data_dir = Path(".test-tmp") / "app-case"
        shutil.rmtree(self.data_dir, ignore_errors=True)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        config = AppConfig(data_dir=self.data_dir, database_name="test.db")
        self.metrics = MetricsRegistry()
        self.application = create_app(config=config, metrics=self.metrics)

    def tearDown(self) -> None:
        shutil.rmtree(self.data_dir, ignore_errors=True)

    def test_dashboard_renders(self) -> None:
        status, _, body = call_app(self.application, "GET", "/")
        self.assertEqual(status, "200 OK")
        self.assertIn(b"SprintBoard", body)

    def test_create_task_redirects(self) -> None:
        status, headers, _ = call_app(
            self.application,
            "POST",
            "/tasks",
            "title=Prepare+demo&description=Write+README",
        )
        self.assertEqual(status, "303 See Other")
        self.assertIn(("Location", "/"), headers)
        self.assertEqual(self.metrics.task_created_total, 1)

    def test_health_endpoint(self) -> None:
        status, _, body = call_app(self.application, "GET", "/healthz")
        self.assertEqual(status, "200 OK")
        self.assertEqual(body, b'{"status":"ok"}')

    def test_metrics_endpoint(self) -> None:
        status, _, body = call_app(self.application, "GET", "/metrics")
        self.assertEqual(status, "200 OK")
        self.assertIn(b"sprintboard_requests_total", body)
