#!/usr/bin/env python3
"""Run unfiltered RustSec audit; evaluate two expiring owner-approved warnings."""
from datetime import date, datetime, timezone
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tomllib
import dependency_scope

ROOT = Path(__file__).resolve().parents[1]
APPROVED = {
    'RUSTSEC-2026-0543': ('chrono', '0.4.45'),
    'RUSTSEC-2024-0370': ('proc-macro-error', '1.0.4'),
}
EXPIRES = date(2026, 12, 27)


def evaluate(report, code, today):
    if code not in (0, 1):
        raise ValueError('Scanner did not complete successfully')
    settings = report['settings']
    if (settings['ignore'] != [] or settings['target_arch'] != []
            or settings['target_os'] != [] or settings['severity'] is not None
            or set(settings['informational_warnings']) != {'notice','unmaintained','unsound'}):
        raise ValueError('Unexpected or filtered RustSec report settings')
    if report['database']['advisory-count'] <= 0 or not report['database']['last-commit']:
        raise ValueError('Unverified advisory database')
    if report['lockfile']['dependency-count'] <= 0:
        raise ValueError('Empty lockfile scan')
    vulnerabilities = report['vulnerabilities']
    if (vulnerabilities['found'] is not False or vulnerabilities['count'] != 0
            or vulnerabilities['list'] != []):
        raise ValueError('Known vulnerabilities are never accepted by this policy')
    accepted = set()
    for kind, warnings in report['warnings'].items():
        if not isinstance(warnings,list):
            raise ValueError('Invalid warnings report')
        for warning in warnings:
            if kind != 'unmaintained' or warning['kind'] != kind:
                raise ValueError(f'Unapproved warning category: {kind}')
            a = warning['advisory']
            identifier = a['id']
            p = warning['package']
            if (identifier not in APPROVED or (p['name'],p['version']) != APPROVED[identifier]
                    or a['package'] != p['name'] or a['informational'] != 'unmaintained'
                    or warning.get('denied') is not True or identifier in accepted):
                raise ValueError(f'Unapproved or changed warning: {identifier}')
            if today >= EXPIRES:
                raise ValueError(f'Risk acceptance expired: {identifier}')
            accepted.add(identifier)
    if code != (1 if accepted else 0):
        raise ValueError('Scanner exit status inconsistent with report')
    return sorted(accepted)


def main():
    # Refuse local audit configurations: no ignore rules, severity filters,
    # stale DB overrides or disabling yanked-package checks.
    cargo_home = Path(os.environ.get('CARGO_HOME', str(Path.home()/'.cargo')))
    candidates = {cargo_home/'audit.toml', Path.home()/'.cargo/audit.toml'}
    candidates.update(p/'.cargo/audit.toml' for p in (ROOT/'src-tauri', ROOT, *ROOT.parents))
    if any(p.exists() for p in candidates):
        raise ValueError('Existing cargo audit configuration; review before running unfiltered scan')
    lock = ROOT/'src-tauri/Cargo.lock'
    before = lock.read_bytes()
    count = len(tomllib.loads(before.decode('utf-8'))['package'])
    scope = {target: dependency_scope.inspect(target) for target in dependency_scope.TARGETS}
    print(json.dumps(scope,indent=2),flush=True)
    dependency_scope.check_scope(scope)
    command = ['cargo','audit','--deny','warnings','--file',str(lock),
               '--url','https://github.com/RustSec/advisory-db','--color','never']
    # The JSON presenter suppresses some registry-index diagnostics. Run
    # the human-readable scan first and fail on incomplete scanner checks.
    terminal = subprocess.run(command,cwd=lock.parent,capture_output=True,
                              text=True,encoding='utf-8')
    print(terminal.stdout,flush=True)
    print(terminal.stderr,file=sys.stderr,end='')
    diagnostic = (terminal.stdout+'\n'+terminal.stderr).lower()
    if any(message in diagnostic for message in
           ("couldn't", "could not", "failed to", "this copy of cargo-audit has known advisories")):
        raise ValueError('Incomplete scanner checks or scanner self-advisory')
    result = subprocess.run(command+['--json','--no-fetch'],cwd=lock.parent,
                            capture_output=True,text=True,encoding='utf-8')
    print(result.stderr,file=sys.stderr,end='')
    print(result.stdout,flush=True)
    if result.stderr.strip():
        raise ValueError('Unexpected diagnostics from JSON scanner')
    if terminal.returncode != result.returncode:
        raise ValueError('Terminal and JSON scans disagree')
    if lock.read_bytes() != before:
        raise ValueError('Lockfile changed during scan')
    report = json.loads(result.stdout)
    if report['lockfile']['dependency-count'] != count:
        raise ValueError('RustSec lockfile dependency count mismatch')
    accepted = evaluate(report,result.returncode,datetime.now(timezone.utc).date())
    reported_ids = set(re.findall(r'^\s*ID:\s+(RUSTSEC-\d{4}-\d+)\s*$', terminal.stdout+'\n'+terminal.stderr, re.M))
    if reported_ids != set(accepted):
        raise ValueError('Terminal and JSON advisory IDs disagree')
    for identifier in accepted:
        print(f'OWNER-ACCEPTED TEMPORARY MAINTENANCE WARNING: {identifier} {APPROVED[identifier]} expires {EXPIRES}')
    print('Dependency policy passed: no known vulnerabilities or unapproved warnings; full raw report retained above.')


if __name__ == '__main__':
    main()
