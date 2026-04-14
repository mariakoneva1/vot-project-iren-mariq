from __future__ import annotations

from wsgiref.simple_server import make_server

from .app import create_app
from .config import AppConfig


def main() -> None:
    config = AppConfig.from_env()
    application = create_app(config)
    with make_server(config.host, config.port, application) as server:
        print(f"Serving {config.app_name} on http://{config.host}:{config.port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
