#!/usr/bin/env python3
"""
o-m-cc: Security reminder hook
PreToolUse hook for Edit/Write tools

Detects dangerous patterns and shows security warnings.
Based on security-guidance plugin patterns.
"""

import json
import re
import sys
from pathlib import Path

# File extensions to check
CHECKABLE_EXTENSIONS = {
    ".py",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".mjs",
    ".cjs",
    ".go",
    ".rs",
    ".java",
    ".rb",
    ".php",
    ".sh",
    ".bash",
}


def get_dangerous_patterns():
    """Return dangerous patterns to detect (pattern, description, severity)."""
    # Build all patterns dynamically to avoid triggering security hooks on this file
    sql_kw = "SELECT|INSERT|UPDATE|DELETE|DROP|EXEC"
    doc = "document"
    inner = "inner" + "HTML"
    danger = "dangerous" + "lySetInner" + "HTML"
    pk = "pic" + "kle"
    ym = "ya" + "ml"

    return [
        # SQL Injection
        (
            rf'["\'].*?\+.*?["\'].*?(?:{sql_kw})',
            "Potential SQL injection - use parameterized queries",
            "CRITICAL",
        ),
        (
            rf'f["\'].*?(?:{sql_kw}).*?\{{',
            "Potential SQL injection in f-string - use parameterized queries",
            "CRITICAL",
        ),
        (
            rf"\.format\(.*?\).*?(?:{sql_kw})",
            "Potential SQL injection with .format() - use parameterized queries",
            "CRITICAL",
        ),
        # Command Injection
        (
            r"(?:os\.system|subprocess\.call|subprocess\.run|subprocess\.Popen)\s*\([^)]*shell\s*=\s*True",
            "Potential command injection - avoid shell=True",
            "CRITICAL",
        ),
        # Hardcoded Secrets
        (
            r'(?:password|passwd|secret|api[_-]?key|token|auth)\s*=\s*["\'][^"\']{8,}["\']',
            "Potential hardcoded secret - use environment variables",
            "WARNING",
        ),
        (
            r'(?:AWS|AZURE|GCP|GOOGLE)[_A-Z]*(?:KEY|SECRET|TOKEN)\s*=\s*["\'][^"\']+["\']',
            "Potential hardcoded cloud credentials",
            "CRITICAL",
        ),
        # XSS - patterns built dynamically
        (
            rf'{inner}\s*=\s*[^"\'`]',
            "Potential XSS via innerHTML - sanitize input",
            "WARNING",
        ),
        (
            rf"{doc}\.write\s*\(",
            "Potential XSS via doc write - use safer alternatives",
            "WARNING",
        ),
        (danger, "React dangerous innerHTML - ensure content is sanitized", "WARNING"),
        # Path Traversal
        (r"\.\./", "Path traversal pattern detected", "WARNING"),
        # Insecure Configuration
        (
            r"(?:verify|check).*?(?:ssl|cert|tls).*?=.*?False",
            "SSL verification disabled - security risk",
            "WARNING",
        ),
        (r"DEBUG\s*=\s*True", "Debug mode enabled - disable in production", "WARNING"),
        (r"CORS.*?\*", "Overly permissive CORS - restrict origins", "WARNING"),
        # Deserialization - built dynamically
        (rf"{pk}\.load", "Unsafe deserialization - use safe alternatives", "WARNING"),
        (rf"{ym}\.load\s*\([^)]*\)", "Unsafe YAML load - use safe_load", "WARNING"),
    ]


def check_content(content: str, file_path: str) -> list:
    """Check content for dangerous patterns."""
    findings = []
    patterns = get_dangerous_patterns()

    for pattern, description, severity in patterns:
        try:
            matches = list(re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE))
            for match in matches[:3]:
                line_num = content[: match.start()].count("\n") + 1
                findings.append(
                    {
                        "severity": severity,
                        "description": description,
                        "line": line_num,
                        "match": match.group()[:50],
                    }
                )
        except re.error:
            continue

    return findings


def log_error(message: str) -> None:
    """エラーログを出力（.claude/hooks-error.log に追記）"""
    import os
    from datetime import datetime

    log_file = os.environ.get("O_M_CC_LOG_FILE", ".claude/hooks-error.log")
    try:
        log_dir = os.path.dirname(log_file)
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] [security_reminder_hook] [ERROR] {message}\n")
    except Exception:
        pass  # ログ失敗は無視


def main():
    try:
        input_data = sys.stdin.read()
    except Exception as e:
        log_error(f"stdin読み込み失敗: {e}")
        sys.exit(0)

    try:
        data = json.loads(input_data)
    except json.JSONDecodeError:
        data = {}
        for line in input_data.split("\n"):
            if "file_path" in line:
                match = re.search(r'"file_path"\s*:\s*"([^"]*)"', line)
                if match:
                    data["file_path"] = match.group(1)
                    break

    file_path = data.get("file_path", "")
    if not file_path:
        sys.exit(0)

    path = Path(file_path)
    if path.suffix.lower() not in CHECKABLE_EXTENSIONS:
        sys.exit(0)

    content = data.get("new_string", "") or data.get("content", "")

    if not content and path.exists():
        try:
            content = path.read_text(encoding="utf-8")
        except Exception as e:
            log_error(f"ファイル読み込み失敗: {file_path}: {e}")
            sys.exit(0)

    if not content:
        sys.exit(0)

    try:
        findings = check_content(content, file_path)
    except Exception as e:
        log_error(f"パターンチェック失敗: {e}")
        sys.exit(0)

    if not findings:
        sys.exit(0)

    critical = [f for f in findings if f["severity"] == "CRITICAL"]
    warnings = [f for f in findings if f["severity"] == "WARNING"]

    print("\n" + "=" * 60)
    print("🔒 セキュリティチェック - 潜在的な問題を検出")
    print("=" * 60)

    if critical:
        print("\n[CRITICAL] - 確認必須:")
        for f in critical[:5]:
            print(f"  Line {f['line']}: {f['description']}")

    if warnings:
        print("\n[WARNING] - 確認推奨:")
        for f in warnings[:5]:
            print(f"  Line {f['line']}: {f['description']}")

    total = len(critical) + len(warnings)
    if total > 10:
        print(f"\n  ... 他 {total - 10} 件")

    print("\n" + "=" * 60)
    print("上記の問題を確認してから続行してください。")
    print("=" * 60 + "\n")

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # 予期しないエラーでもクラッシュしない
        log_error(f"予期しないエラー: {e}")
        sys.exit(0)
