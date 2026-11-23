"""
إحصائيات التحويل في ~/.local/state/hawwel/stats.json.
ما فيهاش الكلام نفسه: عدد مرات وعدد حروف واتجاه واسم البرنامج بس.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import date, timedelta

from .paths import state_dir

CHARS_PER_MINUTE = 200.0  # تقدير الوقت اللي اتوفر: الحروف ÷ 200 حرف في الدقيقة


@dataclass
class StatsData:
    total: int = 0
    chars: int = 0
    to_arabic: int = 0
    to_english: int = 0
    days: dict = field(default_factory=dict)       # "2026-11-22": 12
    day_chars: dict = field(default_factory=dict)
    apps: dict = field(default_factory=dict)       # "Firefox": 31


class Stats:
    def __init__(self, path=None):
        self.path = path or state_dir() / "stats.json"
        self.data = StatsData()
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            self.data = StatsData(**{k: v for k, v in raw.items() if k in StatsData.__dataclass_fields__})
        except (OSError, ValueError, TypeError):
            pass

    def record(self, chars: int, to_arabic: bool, app: str | None) -> None:
        day = date.today().isoformat()
        d = self.data
        d.total += 1
        d.chars += chars
        if to_arabic:
            d.to_arabic += 1
        else:
            d.to_english += 1
        d.days[day] = d.days.get(day, 0) + 1
        d.day_chars[day] = d.day_chars.get(day, 0) + chars
        if app:
            d.apps[app] = d.apps.get(app, 0) + 1
        self._prune()
        self._save()

    def clear(self) -> None:
        self.data = StatsData()
        self._save()

    # ---- أرقام جاهزة للعرض ----

    @property
    def today_count(self) -> int:
        return self.data.days.get(date.today().isoformat(), 0)

    @property
    def today_chars(self) -> int:
        return self.data.day_chars.get(date.today().isoformat(), 0)

    def last7(self) -> list[tuple[date, int]]:
        """آخر 7 أيام (الأقدم الأول، والنهارده آخر واحد)"""
        today = date.today()
        days = [today - timedelta(days=back) for back in range(6, -1, -1)]
        return [(d, self.data.days.get(d.isoformat(), 0)) for d in days]

    @property
    def week_count(self) -> int:
        return sum(n for _, n in self.last7())

    @property
    def to_arabic_share(self) -> float | None:
        all_ = self.data.to_arabic + self.data.to_english
        return None if all_ == 0 else self.data.to_arabic / all_

    def top_apps(self) -> list[tuple[str, float]]:
        all_ = sum(self.data.apps.values())
        if not all_:
            return []
        top = sorted(self.data.apps.items(), key=lambda kv: kv[1], reverse=True)[:3]
        return [(name, n / all_) for name, n in top]

    # ---- حفظ ----

    def _prune(self) -> None:
        """بنحتفظ بآخر 400 يوم بس علشان الملف ما يكبرش"""
        if len(self.data.days) <= 400:
            return
        keep = set(sorted(self.data.days)[-400:])
        self.data.days = {k: v for k, v in self.data.days.items() if k in keep}
        self.data.day_chars = {k: v for k, v in self.data.day_chars.items() if k in keep}

    def _save(self) -> None:
        try:
            self.path.write_text(json.dumps(asdict(self.data)), encoding="utf-8")
        except OSError:
            pass
