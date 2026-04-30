"""共通: jj / git のルートディレクトリ検出ヘルパー."""

from __future__ import annotations

import subprocess
from pathlib import Path


def detect_root() -> Path:
    """jj root → git rev-parse --show-toplevel → cwd の順でフォールバック。"""
    for cmd, args in [("jj", ["root"]), ("git", ["rev-parse", "--show-toplevel"])]:
        try:
            r = subprocess.run([cmd, *args], capture_output=True, text=True, check=True)
            return Path(r.stdout.strip())
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    return Path.cwd()
