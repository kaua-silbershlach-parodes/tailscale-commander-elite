#!/usr/bin/env python3
"""Fail-closed local and CI release preflight; does not read any signing key."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+\Z")


def validate(root, tag=None):
    audit = (root / 'SECURITY_AUDIT.md').read_text(encoding='utf-8')
    book = (root / 'BOOK_CHECKLIST.md').read_text(encoding='utf-8')
    approvals = [line for line in audit.splitlines() if line.startswith('Release authorization:')]
    if approvals != ['Release authorization: APPROVED']:
        raise ValueError('Release authorization missing, ambiguous or not approved')
    entries = [line for line in book.splitlines() if re.match(r'^- \[[ x]\] 1\. Book 1(?: |$)', line)]
    if len(entries) != 1:
        raise ValueError('Book 1 checklist entry is missing or ambiguous')
    # Book 1 closes after a signed release is verified. Before signing,
    # demand a separate explicit pre-signing assessment and approval.
    assessments = [line for line in book.splitlines()
                   if re.match(r'^  - \[[ x]\] Pre-signing assessment complete$', line)]
    if assessments != ['  - [x] Pre-signing assessment complete']:
        raise ValueError('Pre-signing assessment missing, ambiguous or incomplete')
    conf = json.loads((root / 'src-tauri/tauri.conf.json').read_text(encoding='utf-8-sig'))
    version = conf['version']
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise ValueError('Invalid release version')
    cargo = (root / 'src-tauri/Cargo.toml').read_text(encoding='utf-8')
    mix = (root / 'backend/mix.exs').read_text(encoding='utf-8')
    if re.findall(r'^version = "([^"]+)"$', cargo, re.M) != [version]:
        raise ValueError('Cargo version mismatch')
    if re.findall(r'^\s*version: "([^"]+)",\s*$', mix, re.M) != [version]:
        raise ValueError('Mix version mismatch')
    if tag is not None and tag != 'v' + version:
        raise ValueError('Git tag does not match configured release version')
    return version


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tag')
    args = parser.parse_args()
    version = validate(ROOT, args.tag)
    print(f'Recorded release preflight passed for {version}; strict audit and signing controls still required.')


if __name__ == '__main__':
    main()
