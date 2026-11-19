from pathlib import Path

import pytest

from media_filer import filer, parse
from media_filer.agent import AgentResult
from media_filer.hardlink import LinkConflict


@pytest.fixture(autouse=True)
def _low_threshold(monkeypatch):
    monkeypatch.setattr(filer, "MIN_VIDEO_BYTES", 100)


def _job(dir_, name, labels=""):
    return {"TR_TORRENT_DIR": str(dir_), "TR_TORRENT_NAME": name, "TR_TORRENT_LABELS": labels}


def _mk(path: Path, size: int = 4096):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\0" * size)


def never_agent(*a, **k):
    raise AssertionError("agent should not be called for a confident release")


def test_movie_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay.x264-GRP"
    _mk(src / "the.matrix.1999.1080p.mkv", 8192)
    _mk(src / "the.matrix.1999.sample.mkv", 4096)
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    dest = root / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_small_sample_excluded_by_size(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)
    _mk(src / "junk.mkv", 10)
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert (root / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv").exists()


def test_season_pack_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    _mk(src / "Severance.S02E02.1080p.mkv")
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "Severance" / "Season 02"
    assert (tv / "Severance - S02E01.mkv").exists()
    assert (tv / "Severance - S02E02.mkv").exists()


def test_cjk_uses_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "基督山伯爵.2024.1080p.WEB-DL"
    _mk(src / "基督山伯爵.2024.1080p.mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("movie", "The Count of Monte Cristo", 2024, None, None, True)

    filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert (root / "movies" / "The Count of Monte Cristo (2024)"
            / "The Count of Monte Cristo (2024).mkv").exists()


def test_label_forces_anime(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Frieren.S01E05.1080p-GRP"
    _mk(src / "Frieren.S01E05.1080p.mkv")
    filer.process_job(_job(dl, src.name, labels="anime"), root=root, classify=never_agent)
    assert (root / "anime" / "Frieren" / "Season 01" / "Frieren - S01E05.mkv").exists()


def test_agent_unsure_leaves_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "未知资源.XYZ"
    _mk(src / "未知资源.mkv", 8192)

    def unsure(name, files, **k):
        return AgentResult("unknown", None, None, None, None, False)

    results = filer.process_job(_job(dl, src.name), root=root, classify=unsure)
    assert results and all(r.action == "unfiled" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_no_video_files_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Some.Artist.Discography.FLAC"
    _mk(src / "01.track.flac")
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert results and all(r.action == "unfiled" for r in results)


def test_excluded_download_dir_skipped(tmp_path, monkeypatch):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    xxx = dl / "xxx"
    monkeypatch.setattr(filer, "EXCLUDED_DOWNLOAD_DIRS", (xxx,))
    src = xxx / "The.Matrix.1999.1080p.BluRay-GRP"
    _mk(src / "the.matrix.1999.1080p.mkv", 8192)
    results = filer.process_job(_job(xxx, src.name), root=root, classify=never_agent)
    assert results and all(r.action == "skipped" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_excluded_download_subdir_skipped(tmp_path, monkeypatch):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    xxx = dl / "xxx"
    monkeypatch.setattr(filer, "EXCLUDED_DOWNLOAD_DIRS", (xxx,))
    sub = xxx / "studio"
    src = sub / "The.Matrix.1999.1080p-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)
    results = filer.process_job(_job(sub, src.name), root=root, classify=never_agent)
    assert results and all(r.action == "skipped" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_default_excludes_xxx_downloads(tmp_path):
    # The src need not exist: exclusion short-circuits before any filesystem
    # access.
    root = tmp_path / "media"
    results = filer.process_job(
        _job("/tank/media/downloads/xxx", "Some.Movie.2020.1080p-GRP"),
        root=root, classify=never_agent,
    )
    assert results and all(r.action == "skipped" for r in results)


def test_anime_absolute_episode(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "[SubsPlease] One Piece - 1071 (1080p)"
    _mk(src / "[SubsPlease] One Piece - 1071 (1080p).mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("anime", "One Piece", None, None, None, True)

    filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert (root / "anime" / "One Piece" / "One Piece - 1071.mkv").exists()


def test_partial_unfiled_in_batch(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    _mk(src / "Severance.Recap.Special.mkv")
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert (root / "tv" / "Severance" / "Season 02" / "Severance - S02E01.mkv").exists()
    assert any(r.action == "unfiled" for r in results)


def test_link_conflict_reported(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)

    def boom(s, d):
        raise LinkConflict("boom")

    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent, link=boom)
    assert any(r.action == "conflict" for r in results)


def test_movie_without_year_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Some.Mystery.Movie.1080p-GRP"
    _mk(src / "some.mystery.movie.1080p.mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("movie", "Some Mystery Movie", None, None, None, True)

    results = filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert results and all(r.action == "unfiled" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_link_oserror_reported_not_crash(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)

    def boom(s, d):
        raise PermissionError(1, "Operation not permitted")

    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent, link=boom)
    assert any(r.action == "error" for r in results)


def test_movie_links_sidecar_subs(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay-GRP"
    _mk(src / "the.matrix.1999.1080p.mkv", 8192)
    _mk(src / "the.matrix.1999.en.srt", 200)
    (src / "Subs").mkdir(parents=True, exist_ok=True)
    _mk(src / "Subs" / "French.srt", 200)
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    base = root / "movies" / "The Matrix (1999)"
    assert (base / "The Matrix (1999).mkv").exists()
    assert (base / "The Matrix (1999).en.srt").exists()
    assert (base / "The Matrix (1999).fr.srt").exists()


def test_season_pack_links_per_episode_subs(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    _mk(src / "Severance.S02E02.1080p.mkv")
    _mk(src / "Severance.S02E01.en.srt", 200)
    _mk(src / "Severance.S02E02.en.srt", 200)
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "Severance" / "Season 02"
    assert (tv / "Severance - S02E01.en.srt").exists()
    assert (tv / "Severance - S02E02.en.srt").exists()


def test_unmatched_subtitle_logged_not_linked(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    (src / "Subs").mkdir(parents=True, exist_ok=True)
    _mk(src / "Subs" / "2_English.srt", 200)
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert (root / "tv" / "Severance" / "Season 02" / "Severance - S02E01.mkv").exists()
    assert not list(root.rglob("*.srt"))
    assert any(r.action == "unfiled" and r.reason == "subtitle matched no episode" for r in results)


def _hdsky_job(dir_, name):
    return {
        "TR_TORRENT_DIR": str(dir_),
        "TR_TORRENT_NAME": name,
        "TR_TORRENT_TRACKERS": "https://pt.hdsky.me/announce?passkey=SECRET",
    }


def test_hdsky_movie_skips_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky"
    _mk(src / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky.mkv", 8192)
    # guessit also parses these names, so this doesn't isolate the tracker path;
    # the *_when_guessit_blind tests below do that.
    results = filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    dest = root / "movies" / "Full River Red (2023)" / "Full River Red (2023).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_hdsky_season_pack_skips_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "狂飙.The.Knockout.S01.2023.1080p.WEB-DL.H264.AAC@HDSky"
    _mk(src / "狂飙.The.Knockout.S01.E01.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    _mk(src / "狂飙.The.Knockout.S01.E02.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    # guessit also parses these names, so this doesn't isolate the tracker path;
    # the *_when_guessit_blind tests below do that.
    filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "The Knockout" / "Season 01"
    assert (tv / "The Knockout - S01E01.mkv").exists()
    assert (tv / "The Knockout - S01E02.mkv").exists()


def test_hdsky_movie_files_via_tracker_when_guessit_blind(tmp_path, monkeypatch):
    # With guessit blinded, only trackers.release can yield a confident
    # decision; otherwise this escalates to never_agent and raises.
    monkeypatch.setattr(
        parse, "parse_name", lambda name: parse.Candidate(None, None, None, None, None)
    )
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky"
    _mk(src / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky.mkv", 8192)
    results = filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    dest = root / "movies" / "Full River Red (2023)" / "Full River Red (2023).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_hdsky_season_pack_files_via_tracker_when_guessit_blind(tmp_path, monkeypatch):
    # With guessit blinded, only trackers.release (show + season) and
    # trackers.file (per-episode numbers) can file these.
    monkeypatch.setattr(
        parse, "parse_name", lambda name: parse.Candidate(None, None, None, None, None)
    )
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "狂飙.The.Knockout.S01.2023.1080p.WEB-DL.H264.AAC@HDSky"
    _mk(src / "狂飙.The.Knockout.S01.E01.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    _mk(src / "狂飙.The.Knockout.S01.E02.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "The Knockout" / "Season 01"
    assert (tv / "The Knockout - S01E01.mkv").exists()
    assert (tv / "The Knockout - S01E02.mkv").exists()
