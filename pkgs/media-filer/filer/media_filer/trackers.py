"""Private trackers use rigid naming conventions that guessit mis-parses
(CJK titles, @group)."""
from __future__ import annotations

import re
from urllib.parse import urlparse

from .parse import Candidate

# Announce URLs use varying subdomains (pt.hdsky.me, tracker.hdsky.me, ...).
_HOSTS: dict[str, str] = {"hdsky": "hdsky"}

_YEAR = r"(?:19|20)\d{2}"


def _clean(title: str) -> str:
    return title.replace(".", " ").strip()


def tracker_for(trackers_env: str) -> str | None:
    if not trackers_env:
        return None
    for token in re.split(r"[\s,]+", trackers_env.strip()):
        host = (urlparse(token).hostname or "").lower()
        for needle, tid in _HOSTS.items():
            if needle in host:
                return tid
    return None


class HDSky:
    # HDSky names lead with a single CJK title token.
    _MOVIE = re.compile(rf"^[^.]+\.(?P<title>.+)\.(?P<year>{_YEAR})(?:\.|@)")
    _TV = re.compile(
        r"^[^.]+\.(?P<title>.+?)\.S(?P<season>\d{1,2})(?:\.E(?P<episode>\d{1,3}))?(?:\.|@|$)"
    )
    _FILE = re.compile(r"\.S(?P<season>\d{1,2})\.E(?P<episode>\d{1,3})\b")

    def release(self, name: str) -> Candidate | None:
        # TV first: a TV name also contains a year the movie regex would grab.
        m = self._TV.match(name)
        if m:
            ep = m.group("episode")
            return Candidate(
                type="episode",
                title=_clean(m.group("title")),
                year=None,
                season=int(m.group("season")),
                episode=int(ep) if ep else None,
            )
        m = self._MOVIE.match(name)
        if m:
            return Candidate(
                type="movie",
                title=_clean(m.group("title")),
                year=int(m.group("year")),
                season=None,
                episode=None,
            )
        return None

    def file(self, name: str) -> tuple[int | None, int | None] | None:
        m = self._FILE.search(name)
        if not m:
            return None
        return int(m.group("season")), int(m.group("episode"))


_REGISTRY: dict[str, HDSky] = {"hdsky": HDSky()}


def release(tracker: str, name: str) -> Candidate | None:
    parser = _REGISTRY.get(tracker)
    return parser.release(name) if parser else None


def file(tracker: str, name: str) -> tuple[int | None, int | None] | None:
    parser = _REGISTRY.get(tracker)
    return parser.file(name) if parser else None
