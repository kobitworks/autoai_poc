#!/usr/bin/env python3
"""Fail closed on high-confidence credential material in tracked public PoC files.

Only filenames, line numbers and detection types are logged. Never log a token.
This is a supplement to GitHub secret scanning, not a replacement.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

TEXT_SUFFIXES = {
    ".js", ".ts", ".tsx", ".jsx", ".json", ".jsonc", ".html",
    ".css", ".py", ".php", ".yaml", ".yml", ".toml",
    ".txt", ".md", ".sh", ".env", ".cfg", ".xml", ".gd",
}
PATTERNS = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |DSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "github_token": re.compile(r"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})"),
    "openai_secret": re.compile(r"sk-(?:proj-)?[A-Za-z0-9_-]{32,}"),
    "stripe_live_secret": re.compile(r"sk_live_[A-Za-z0-9]{16,}"),
    "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "slack_token": re.compile(r"xox[baprs]-[A-Za-z0-9-]{20,}"),
    "service_account_key": re.compile(r'"private_key"\s*:\s*"-----BEGIN'),
}


def main() -> int:
    result = subprocess.run(["git", "ls-files", "-z"], check=True, capture_output=True)
    tracked = (raw for raw in result.stdout.split(b"\0") if raw)
    issues: list[tuple[str, int, str]] = []
    checked = 0

    for raw in tracked:
        name = raw.decode("utf-8", "replace")
        path = Path(name)
        if (path.suffix.lower() not in TEXT_SUFFIXES or not path.is_file()):
            continue
        if path.stat().st_size > 1_000_000:
            continue
        try:
            contents = path.read_text(encoding="utf-8")
        except (UnicodeError, OSError):
            continue

        checked += 1
        for line_number, line in enumerate(contents.splitlines(), start=1):
            for label, pattern in PATTERNS.items():
                if pattern.search(line):
                    issues.append((name, line_number, label))

    for name, line, label in issues[:30]:
        # Do not print the matched secret or its surrounding content.
        print(f"::error file={name},line={line}::Potential {label} committed to public repository")
    print(f"Security scan inspected {checked} tracked text files. Matches: {len(issues)}")
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
