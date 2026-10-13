#!/usr/bin/env python3
"""Basic guard against missing keys in the interim AR/FR string map."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = '\n'.join(p.read_text(encoding='utf-8') for p in (root / 'lib').rglob('*.dart'))
strings = (root / 'lib/app/strings.dart').read_text(encoding='utf-8')
used = set(re.findall(r"\.t\('([^']+)'\)", source))
defined = set(re.findall(r"^\s*'([^']+)'\s*:\s*\{", strings, re.M))
missing = sorted(used - defined)
if missing:
    raise SystemExit(f'Missing localization keys: {missing}')
entries = re.findall(r"^\s*'([^']+)'\s*:\s*\{(.*?)\}", strings, re.M | re.S)
incomplete = sorted(k for k, body in entries if "'ar':" not in body or "'fr':" not in body)
if incomplete:
    raise SystemExit(f'Entries missing Arabic/French: {incomplete}')
print(f'PASS localization keys: {len(used)} used, no missing keys; {len(entries)} bilingual entries.')
