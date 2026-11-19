from __future__ import annotations

import os
from pathlib import Path


class LinkConflict(Exception):
    """Destination exists and points at different content."""


def hardlink(src: Path, dest: Path) -> str:
    if dest.exists():
        if dest.samefile(src):
            return "exists"
        raise LinkConflict(f"{dest} exists with different content")
    dest.parent.mkdir(parents=True, exist_ok=True)
    os.link(src, dest)
    return "linked"
