"""نصوص الواجهة بالعربي والإنجليزي (data/strings.json). لغة الواجهة مستقلة عن لغة النظام."""

from __future__ import annotations

import json
import time

from .paths import DATA_DIR
from .stats import CHARS_PER_MINUTE

_STRINGS: dict = json.loads((DATA_DIR / "strings.json").read_text(encoding="utf-8"))
_lang = "ar"


def set_language(lang: str) -> None:
    global _lang
    _lang = "en" if lang == "en" else "ar"


def language() -> str:
    return _lang


def is_arabic() -> bool:
    return _lang == "ar"


def T(key: str, *args) -> str:
    s = _STRINGS.get(key, {}).get(_lang, key)
    s = s.format(*args) if args else s
    # علامة RLM في الأول: الجملة العربي تفضل من اليمين للشمال حتى لو بدأت بكلمة إنجليزي (Hawwel…)
    return "\u200f" + s if _lang == "ar" else s


# ---- أرقام: دايماً بالأرقام الإنجليزية في اللغتين، زي التصميم ----

def grouped(n: int) -> str:
    return f"{n:,}"


def compact(n: int) -> str:
    """486 / 1.2K / 52K"""
    if n < 1000:
        return str(n)
    if n < 10_000:
        v = round(n / 1000, 1)
        return f"{v:g}K"
    if n < 1_000_000:
        return f"{n // 1000}K"
    return f"{n / 1_000_000:.1f}M"


def time_saved(chars: int) -> str:
    if chars == 0:
        return "0"
    minutes = chars / CHARS_PER_MINUTE
    if minutes < 1:
        return T("time.lessThanMin")
    if minutes < 60:
        return T("time.min", round(minutes))
    hours = minutes / 60
    return T("time.hour", f"{hours:.1f}" if hours < 10 else str(round(hours)))


def ago(ts: float) -> str:
    d = time.time() - ts
    if d < 60:
        return T("time.ago.now")
    if d < 3600:
        return T("time.ago.min", int(d // 60))
    if d < 86400:
        return T("time.ago.hour", int(d // 3600))
    return T("time.ago.day", int(d // 86400))
