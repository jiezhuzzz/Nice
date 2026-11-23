from __future__ import annotations

import functools
from dataclasses import dataclass

import guessit


@dataclass(frozen=True)
class Candidate:
    type: str | None
    title: str | None
    year: int | None
    season: int | None
    episode: int | None


def _scalar(value):
    """guessit returns lists for multi-valued fields (e.g. two years)."""
    if isinstance(value, list):
        return value[0] if value else None
    return value


def is_cjk(s: str | None) -> bool:
    """guessit mis-parses CJK / fullwidth characters."""
    if not s:
        return False
    for ch in s:
        if "　" <= ch <= "鿿" or "＀" <= ch <= "￯":
            return True
    return False


@functools.cache
def parse_name(name: str) -> Candidate:
    g = guessit.guessit(name)
    gtype = _scalar(g.get("type"))
    return Candidate(
        type=gtype if gtype in ("movie", "episode") else None,
        title=_scalar(g.get("title")),
        year=_scalar(g.get("year")),
        season=_scalar(g.get("season")),
        episode=_scalar(g.get("episode")),
    )


def confident(c: Candidate) -> bool:
    if not c.title or is_cjk(c.title):
        return False
    if c.type == "movie":
        return c.year is not None
    if c.type == "episode":
        # Season packs carry no episode in the torrent name; it is resolved
        # per file.
        return c.season is not None
    return False
