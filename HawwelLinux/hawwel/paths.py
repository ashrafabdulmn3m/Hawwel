"""أماكن الملفات (حسب معايير XDG في لينكس)."""

from __future__ import annotations

import os
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data"


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    p = Path(base) / "hawwel"
    p.mkdir(parents=True, exist_ok=True)
    return p


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    p = Path(base) / "hawwel"
    p.mkdir(parents=True, exist_ok=True)
    return p


def socket_path() -> str:
    """الـ socket اللي أمر "hawwel --convert" بيكلّم بيه البرنامج الشغّال"""
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/hawwel-{os.getuid()}"
    os.makedirs(runtime, exist_ok=True)
    return os.path.join(runtime, "hawwel.sock")
