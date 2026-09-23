#!/usr/bin/env python3
"""redact-secrets.py — scrub secret-shaped values from text at the build boundary.

stdin -> stdout, or `--in-place DIR` to rewrite every *.md under DIR. Replaces the VALUE of a
credential with `[REDACTED:<kind>]` and keeps the key, so the line stays readable. Kinds mirror
the secrets-scan hook (home/.claude/hooks/secrets-scan.sh): assign (api_key/secret/token/
password/... = value), stripe, github, slack, aws, pem, plus bearer and jwt. Placeholders pass
through under the hook's rule. A line that matches nothing is byte-identical. python3 only.
"""
import os, re, sys

PLACEHOLDER = re.compile(r'^(?:<[^>]+>|your[_-].*|xxx+|changeme\b.*|placeholder\b.*|dummy\b.*|example\b.*|example[_-].*)$', re.I)
ASSIGN = re.compile(r'(?P<key>(?:api[_-]?key|secret|token|passwd|password|access[_-]?key|private[_-]?key|client[_-]?secret)[A-Za-z0-9_-]*\s*[:=]\s*["\']?)(?P<val>[A-Za-z0-9/+_.-]{12,})(?P<q>["\']?)', re.I)
PREFIX = [
    ("stripe", re.compile(r'\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{8,}')),
    ("github", re.compile(r'\b(?:gh[posru]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})')),
    ("slack",  re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}')),
    ("aws",    re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ("jwt",    re.compile(r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}')),
    ("bearer", re.compile(r'(?<=\bBearer )[A-Za-z0-9._-]{16,}')),
]
PEM = re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----', re.S)

def _assign(m):
    val = m.group('val')
    if PLACEHOLDER.match(val) or 'REDACTED' in val:
        return m.group(0)
    return f"{m.group('key')}[REDACTED:assign]{m.group('q')}"

def redact(text: str) -> str:
    text = PEM.sub('[REDACTED:pem]', text)
    for kind, rx in PREFIX:
        text = rx.sub(f'[REDACTED:{kind}]', text)
    return ASSIGN.sub(_assign, text)

def main(argv):
    if len(argv) >= 2 and argv[0] == '--in-place':
        root = argv[1]; n = 0
        for d, _, files in os.walk(root):
            for f in files:
                if not f.endswith('.md'): continue
                p = os.path.join(d, f)
                with open(p, encoding='utf-8', errors='surrogateescape') as fh: s = fh.read()
                r = redact(s)
                if r != s:
                    with open(p, 'w', encoding='utf-8', errors='surrogateescape') as fh: fh.write(r)
                    n += 1
        print(f"redacted {n} file(s) under {root}")
        return 0
    sys.stdout.write(redact(sys.stdin.read()))
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
