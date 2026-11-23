"""بيسأل GitHub Releases عن إصدار لينكس أحدث (tags بتبدأ بـ linux-v)."""

from __future__ import annotations

import json
import urllib.request

from . import __version__

OWNER, REPO, PREFIX = "ashrafabdulmn3m", "Hawwel", "linux-v"
RELEASES_PAGE = f"https://github.com/{OWNER}/{REPO}/releases"


def _ver(s: str) -> tuple[int, ...]:
    parts = []
    for p in s.split("."):
        try:
            parts.append(int(p))
        except ValueError:
            parts.append(0)
    return tuple((parts + [0, 0, 0])[:3])


def current() -> str:
    return __version__


def check(timeout: float = 15) -> tuple[str, str] | None:
    """(رقم الإصدار، رابط صفحته) لو فيه أحدث، وإلا None. بيرمي exception لو مفيش نت."""
    req = urllib.request.Request(
        f"https://api.github.com/repos/{OWNER}/{REPO}/releases?per_page=30",
        headers={"User-Agent": "Hawwel-Updater", "Accept": "application/vnd.github+json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        releases = json.load(r)
    best = None
    for rel in releases:
        tag = rel.get("tag_name", "")
        if rel.get("draft") or rel.get("prerelease") or not tag.startswith(PREFIX):
            continue
        v = tag[len(PREFIX):]
        if best is None or _ver(v) > _ver(best[0]):
            best = (v, rel.get("html_url") or RELEASES_PAGE)
    if best and _ver(best[0]) > _ver(__version__):
        return best
    return None
