"""الإعدادات في ~/.config/hawwel/settings.json"""

from __future__ import annotations

import json
import locale
import os
from dataclasses import asdict, dataclass, field, fields

from .paths import config_dir

_FILE = config_dir() / "settings.json"


@dataclass
class Settings:
    # الاختصار بصيغة GNOME (نفس الافتراضي بتاع ويندوز: Ctrl+Alt+K)
    shortcut: str = "<Primary><Alt>k"
    show_tray: bool = True
    theme: str = "system"            # light | dark | system
    language: str = ""               # ar | en (فاضي = أول مرة)
    sidebar_collapsed: bool = False
    play_sound: bool = False
    auto_check_updates: bool = True
    last_update_check: float = 0.0   # unix time
    last_notified_update: str = ""
    has_launched_before: bool = False

    @staticmethod
    def load() -> "Settings":
        s = Settings()
        try:
            data = json.loads(_FILE.read_text(encoding="utf-8"))
            known = {f.name for f in fields(Settings)}
            for k, v in data.items():
                if k in known:
                    setattr(s, k, v)
        except (OSError, ValueError):
            pass  # أول مرة أو ملف تالف: الافتراضي
        if not s.language:
            s.language = "ar" if s.has_launched_before or _system_is_arabic() else "en"
        if s.theme not in ("light", "dark", "system"):
            s.theme = "system"
        return s

    def save(self) -> None:
        try:
            _FILE.write_text(json.dumps(asdict(self), ensure_ascii=False, indent=1), encoding="utf-8")
        except OSError:
            pass

    def reset_to_defaults(self) -> None:
        """"رجّع كل الإعدادات": اللغة والإحصائيات والتشغيل مع الجهاز بيفضلوا زي ما هم."""
        d = Settings()
        for name in ("shortcut", "show_tray", "theme", "sidebar_collapsed", "play_sound", "auto_check_updates"):
            setattr(self, name, getattr(d, name))
        self.save()


def _system_is_arabic() -> bool:
    lang = os.environ.get("LANG", "") or (locale.getlocale()[0] or "")
    return lang.startswith("ar")


# ---- التشغيل مع بداية الجهاز (~/.config/autostart) ----

def _autostart_file():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "autostart", "hawwel.desktop")


def launch_at_login() -> bool:
    return os.path.exists(_autostart_file())


def set_launch_at_login(on: bool, command: str) -> None:
    path = _autostart_file()
    if on:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(
                "[Desktop Entry]\nType=Application\nName=Hawwel\n"
                f"Exec={command} --background\nIcon=hawwel\nX-GNOME-Autostart-enabled=true\nNoDisplay=true\n"
            )
    elif os.path.exists(path):
        os.remove(path)


__all__ = ["Settings", "launch_at_login", "set_launch_at_login", "field"]
