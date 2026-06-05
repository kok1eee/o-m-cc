"""共通: jj / git のルートディレクトリ検出 + データ層ディレクトリ解決ヘルパー."""

from __future__ import annotations

import os
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


def data_dir() -> Path:
    """o-m-cc データ層（atoms/pipeline/outputs 等）の置き場を解決する。

    `O_M_CC_DATA_DIR` が設定されていればそれを使う（個人バックログを公開 o-m-cc repo の外、
    私的リポに分離するための indirection）。未設定なら従来通り `<repo root>/.claude`（後方互換）。
    """
    env = os.environ.get("O_M_CC_DATA_DIR")
    if env:
        return Path(env).expanduser()
    return detect_root() / ".claude"
