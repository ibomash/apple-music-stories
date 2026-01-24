from __future__ import annotations

from pathlib import Path
import re


ICON_NAME = "MusicStories-AppIcon-Composed.icon"
ICON_FILE_TYPE = "folder.iconcomposer.icon"


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    pbxproj_path = (
        project_root
        / "ios"
        / "MusicStoryRenderer"
        / "MusicStoryRenderer.xcodeproj"
        / "project.pbxproj"
    )

    if not pbxproj_path.exists():
        raise SystemExit(f"Missing project file at {pbxproj_path}")

    contents = pbxproj_path.read_text(encoding="utf-8")
    pattern = rf"/\* {re.escape(ICON_NAME)} \*/ = \{{isa = PBXFileReference;[^}}]+\}};"

    def apply_filetype(match: re.Match[str]) -> str:
        block = match.group(0)
        if "lastKnownFileType" in block:
            block = re.sub(
                r"lastKnownFileType = [^;]+;",
                f"lastKnownFileType = {ICON_FILE_TYPE};",
                block,
            )
        else:
            block = block.replace(
                "isa = PBXFileReference;",
                f"isa = PBXFileReference; lastKnownFileType = {ICON_FILE_TYPE};",
            )
        return block

    updated, count = re.subn(pattern, apply_filetype, contents)
    if count == 0:
        raise SystemExit("Icon file reference not found in project.pbxproj")

    if updated != contents:
        pbxproj_path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
