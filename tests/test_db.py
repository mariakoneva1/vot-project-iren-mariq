from __future__ import annotations

import shutil
import unittest
from pathlib import Path

from app.db import advance_task, create_task, initialize_database, list_tasks


class DatabaseTestCase(unittest.TestCase):
    def test_task_advances_through_workflow(self) -> None:
        data_dir = Path(".test-tmp") / "db-case"
        shutil.rmtree(data_dir, ignore_errors=True)
        data_dir.mkdir(parents=True, exist_ok=True)
        database_path = data_dir / "tasks.db"
        initialize_database(database_path)
        task_id = create_task(database_path, "Ship the app", "Prepare deployment manifests")

        first_transition = advance_task(database_path, task_id)
        second_transition = advance_task(database_path, task_id)
        third_transition = advance_task(database_path, task_id)

        self.assertEqual(first_transition, "DOING")
        self.assertEqual(second_transition, "DONE")
        self.assertEqual(third_transition, "DONE")
        self.assertEqual(list_tasks(database_path)[0]["status"], "DONE")
        shutil.rmtree(data_dir, ignore_errors=True)
