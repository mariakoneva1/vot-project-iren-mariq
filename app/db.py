from __future__ import annotations

import sqlite3
from pathlib import Path

STATUSES = ("TODO", "DOING", "DONE")


def initialize_database(database_path: Path) -> None:
    database_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(database_path) as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL DEFAULT 'TODO',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        connection.commit()


def list_tasks(database_path: Path) -> list[dict[str, str | int]]:
    with sqlite3.connect(database_path) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            """
            SELECT id, title, description, status, created_at, updated_at
            FROM tasks
            ORDER BY
                CASE status
                    WHEN 'TODO' THEN 1
                    WHEN 'DOING' THEN 2
                    ELSE 3
                END,
                created_at DESC
            """
        ).fetchall()
    return [dict(row) for row in rows]


def create_task(database_path: Path, title: str, description: str) -> int:
    with sqlite3.connect(database_path) as connection:
        cursor = connection.execute(
            """
            INSERT INTO tasks (title, description)
            VALUES (?, ?)
            """,
            (title.strip(), description.strip()),
        )
        connection.commit()
    return int(cursor.lastrowid)


def advance_task(database_path: Path, task_id: int) -> str | None:
    with sqlite3.connect(database_path) as connection:
        row = connection.execute(
            "SELECT status FROM tasks WHERE id = ?",
            (task_id,),
        ).fetchone()
        if row is None:
            return None

        current_status = row[0]
        try:
            next_status = STATUSES[min(STATUSES.index(current_status) + 1, len(STATUSES) - 1)]
        except ValueError:
            next_status = "TODO"

        connection.execute(
            """
            UPDATE tasks
            SET status = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
            """,
            (next_status, task_id),
        )
        connection.commit()
    return next_status
