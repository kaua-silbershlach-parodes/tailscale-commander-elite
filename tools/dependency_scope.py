#!/usr/bin/env python3
"""Report build-target dependency scope; never waive a RustSec advisory."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1] / 'src-tauri'
TARGETS = ('x86_64-pc-windows-msvc', 'x86_64-unknown-linux-gnu')
WATCH = ('chrono', 'proc-macro-error', 'glib')


def active_packages(tree):
    result = {name: set() for name in WATCH}
    for line in tree.splitlines():
        match = re.match(r'^([A-Za-z0-9_-]+) v(\S+)(?: |$)', line)
        if match and match[1] in result:
            result[match[1]].add(match[2])
    return {name: sorted(versions) for name, versions in result.items()}


def check_scope(report):
    for target in TARGETS:
        if report[target]['active']['chrono']:
            raise ValueError(f'Chrono appeared in build tree on {target}; reassess')
    if report[TARGETS[0]]['active']['proc-macro-error']:
        raise ValueError('proc-macro-error became active on Windows')
    linux = report[TARGETS[1]]
    if linux['active']['proc-macro-error'] != ['1.0.4']:
        raise ValueError('Linux proc-macro-error versions changed; reassess')
    parents = linux['macro_parents']
    if set(parents) != {'glib-macros', 'gtk3-macros'}:
        raise ValueError('Linux macro dependency parents changed; reassess')
    if any('proc-macro' not in kinds for kinds in parents.values()):
        raise ValueError('Linux macro-only scope changed')


def inspect(target):
    tree = subprocess.check_output(['cargo', 'tree', '--locked', '--target', target,
                                    '--edges', 'normal,build,dev', '--prefix', 'none',
                                    '--format', '{p}'], cwd=ROOT, text=True, encoding='utf-8')
    if not tree.strip() or not tree.startswith('tailscale-commander-elite v'):
        raise ValueError('Unexpected or empty Cargo tree')
    metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--locked',
                        '--format-version', '1', '--filter-platform', target], cwd=ROOT))
    packages = {p['id']: p for p in metadata['packages']}
    macro_ids = {p['id'] for p in packages.values() if p['name'] == 'proc-macro-error'}
    parents = {packages[n['id']]['name']: sorted({k for t in packages[n['id']]['targets'] for k in t['kind']})
               for n in metadata['resolve']['nodes'] if any(d['pkg'] in macro_ids for d in n['deps'])}
    return {'active': active_packages(tree), 'macro_parents': parents,
            'metadata_chrono_versions': sorted({p['version'] for p in packages.values()
                                                if p['name'] == 'chrono'})}


def main():
    report = {target: inspect(target) for target in TARGETS}
    print(json.dumps(report, indent=2, sort_keys=True))
    check_scope(report)
    print('Scope evidence matches current build trees. Strict Cargo Audit remains mandatory.')


if __name__ == '__main__':
    main()
