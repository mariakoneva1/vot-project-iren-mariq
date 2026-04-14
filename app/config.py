from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class AppConfig:
    app_name: str = "SprintBoard"
    environment: str = "development"
    host: str = "0.0.0.0"
    port: int = 8000
    data_dir: Path = Path("data")
    database_name: str = "sprintboard.db"
    base_url: str = "http://localhost:8000"

    @property
    def database_path(self) -> Path:
        return self.data_dir / self.database_name

    @classmethod
    def from_env(cls) -> AppConfig:
        data_dir = Path(os.getenv("DATA_DIR", "data"))
        return cls(
            app_name=os.getenv("APP_NAME", "SprintBoard"),
            environment=os.getenv("APP_ENV", "development"),
            host=os.getenv("APP_HOST", "0.0.0.0"),
            port=int(os.getenv("PORT", "8000")),
            data_dir=data_dir,
            database_name=os.getenv("DATABASE_NAME", "sprintboard.db"),
            base_url=os.getenv("BASE_URL", "http://localhost:8000"),
        )
