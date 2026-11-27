#!/usr/bin/env python3
"""Run unfiltered RustSec audit; evaluate two expiring owner-approved warnings."""
from datetime import date, datetime, timezone, timedelta
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import dependency_scope

ROOT = Path(__file__).resolve().parents[1]
APPROVED = {
    'RUSTSEC-2026-0543': ('chrono', '0.4.45'),
    'RUSTSEC-2024-0370': ('proc-macro-error', '1.0.4'),
}
EXPIRES = date(2026, 12, 27)
DB_URL = "https://github.com/RustSec/advisory-db"


def evaluate(report, code, today, verified_revision):
    if code not in (0, 1):
        raise ValueError('Scanner did not complete successfully')
    settings = report['settings']
    if (settings['ignore'] != [] or settings['target_arch'] != []
            or settings['target_os'] != [] or settings['severity'] is not None
            or set(settings['informational_warnings']) != {'notice','unmaintained','unsound'}):
        raise ValueError('Unexpected or filtered RustSec report settings')
    db = report['database']
    if (not isinstance(verified_revision, str)
            or not re.fullmatch(r'[0-9a-f]{40}', verified_revision)
            or db['advisory-count'] <= 0
            or db['last-commit'] not in (None, verified_revision)):
        raise ValueError('Unverified advisory database')
    # cargo-audit --no-fetch uses Database::open, which leaves revision
    # and timestamp null. The independently verified checkout is mandatory.
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



def lock_package_count(lock_bytes):
    """Count canonical Cargo-generated package headers; fail on empty input.

    Cargo Audit independently parses the TOML lockfile. This is only a
    cross-check of its reported package count, not a TOML parser.
    Compatible with the Python 3.10 system interpreter on Ubuntu 22.04.
    """
    count = len(re.findall(rb'(?m)^\[\[package\]\]\r?$', lock_bytes))
    if count == 0:
        raise ValueError('No canonical Cargo lockfile package headers')
    return count



def git_db(*args, cwd=None):
    return subprocess.check_output(['git', *args], cwd=cwd, text=True,
                                   encoding='utf-8', timeout=120).strip()


def verify_checkout(db, expected=None):
    revision = git_db('rev-parse', 'HEAD', cwd=db)
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Invalid advisory checkout revision')
    if expected is not None and revision != expected:
        raise ValueError('Advisory checkout changed during scan')
    if git_db('remote', 'get-url', 'origin', cwd=db) != DB_URL:
        raise ValueError('Unexpected advisory origin')
    if git_db('status', '--porcelain', '--untracked-files=all', '--ignored', cwd=db):
        raise ValueError('Advisory checkout contains unexpected changes')
    timestamp = datetime.fromtimestamp(int(git_db('log', '-1', '--format=%ct', cwd=db)),
                                      timezone.utc)
    now = datetime.now(timezone.utc)
    if timestamp > now + timedelta(minutes=10) or now - timestamp > timedelta(days=90):
        raise ValueError('Advisory checkout timestamp is stale or invalid')
    return revision, timestamp


def fresh_checkout(db):
    subprocess.run(['git','clone','--depth','1','--single-branch',DB_URL,str(db)],
                   check=True,timeout=180)
    revision, timestamp = verify_checkout(db)
    remote = git_db('ls-remote', '--exit-code', DB_URL, 'HEAD').split()
    if remote != [revision, 'HEAD']:
        raise ValueError('Advisory checkout is not current upstream HEAD; retry')
    print(f'Verified RustSec origin {DB_URL}, HEAD {revision}, commit UTC {timestamp.isoformat()}',
          flush=True)
    return revision


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
    count = lock_package_count(before)
    scope = {target: dependency_scope.inspect(target) for target in dependency_scope.TARGETS}
    print(json.dumps(scope,indent=2),flush=True)
    dependency_scope.check_scope(scope)
    with tempfile.TemporaryDirectory(prefix='tce-rustsec-') as temp:
        db = Path(temp) / 'advisory-db'
        revision = fresh_checkout(db)
        command = ['cargo','audit','--deny','warnings','--file',str(lock),
                   '--db',str(db),'--url',DB_URL,'--color','never','--no-fetch']
        # Both scans use the identical independently verified fresh checkout.
        # The terminal presenter exposes registry-index diagnostics.
        terminal = subprocess.run(command,cwd=lock.parent,capture_output=True,
                                  text=True,encoding='utf-8',timeout=180)
        print(terminal.stdout,flush=True)
        print(terminal.stderr,file=sys.stderr,end='')
        diagnostic = (terminal.stdout+'\n'+terminal.stderr).lower()
        if any(message in diagnostic for message in
               ("couldn't", "could not", "failed to", "this copy of cargo-audit has known advisories")):
            raise ValueError('Incomplete scanner checks or scanner self-advisory')
        result = subprocess.run(command+['--json'],cwd=lock.parent,
                                capture_output=True,text=True,encoding='utf-8',timeout=180)
        print(result.stderr,file=sys.stderr,end='')
        print(result.stdout,flush=True)
        if result.stderr.strip():
            raise ValueError('Unexpected diagnostics from JSON scanner')
        if terminal.returncode != result.returncode:
            raise ValueError('Terminal and JSON scans disagree')
        verify_checkout(db, revision)
    if lock.read_bytes() != before:
        raise ValueError('Lockfile changed during scan')
    report = json.loads(result.stdout)
    if report['lockfile']['dependency-count'] != count:
        raise ValueError('RustSec lockfile dependency count mismatch')
    accepted = evaluate(report,result.returncode,datetime.now(timezone.utc).date(),revision)
    reported_ids = set(re.findall(r'^\s*ID:\s+(RUSTSEC-\d{4}-\d+)\s*$', terminal.stdout+'\n'+terminal.stderr, re.M))
    if reported_ids != set(accepted):
        raise ValueError('Terminal and JSON advisory IDs disagree')
    for identifier in accepted:
        print(f'OWNER-ACCEPTED TEMPORARY MAINTENANCE WARNING: {identifier} {APPROVED[identifier]} expires {EXPIRES}')
    print('Dependency policy passed: no known vulnerabilities or unapproved warnings; full raw report retained above.')


if __name__ == '__main__':
    main()
