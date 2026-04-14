from __future__ import annotations

import sys
from pathlib import Path


def update_values_file(path: Path, repository: str, tag: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    inside_image_block = False
    updated_lines: list[str] = []

    for line in lines:
        stripped = line.strip()
        if stripped == "image:":
            inside_image_block = True
            updated_lines.append(line)
            continue

        if inside_image_block and stripped.startswith("repository:"):
            indent = line[: len(line) - len(line.lstrip())]
            updated_lines.append(f"{indent}repository: {repository}")
            continue

        if inside_image_block and stripped.startswith("tag:"):
            indent = line[: len(line) - len(line.lstrip())]
            updated_lines.append(f'{indent}tag: "{tag}"')
            inside_image_block = False
            continue

        if inside_image_block and line and not line.startswith(" "):
            inside_image_block = False

        updated_lines.append(line)

    path.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("Usage: update_image_tag.py <path> <repository> <tag>")
    update_values_file(Path(sys.argv[1]), sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()

