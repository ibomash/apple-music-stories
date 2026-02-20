from __future__ import annotations

import uvicorn

from story_writer.config import AppConfig


def main() -> None:
    config = AppConfig.from_env()
    uvicorn.run(
        "story_writer.api:app",
        host=config.host,
        port=config.port,
        reload=False,
    )


if __name__ == "__main__":
    main()
