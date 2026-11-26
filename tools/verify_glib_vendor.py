#!/usr/bin/env python3
"""Verify the complete glib 0.18.5 backport against the registry archive.

Only the upstream two-line mutability fix is allowed. No change to package
version, license, build script, or other vendor files is permitted.
"""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import tarfile
import urllib.request

URL = 'https://static.crates.io/crates/glib/glib-0.18.5.crate'
SHA = '233daaf6e83ae6a12a52055f568f9d7cf4671dabb78ff9560ab6da230ce00ee5'
ROOT = Path(__file__).resolve().parents[1] / 'src-tauri' / 'vendor' / 'glib-0.18.5'
PATCH_FILE = 'src/variant_iter.rs'

def expected_files():
    req = urllib.request.Request(URL, headers={'User-Agent': 'TCE-vendor-audit'})
    with urllib.request.urlopen(req, timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        data = response.read(3_000_001)
    if len(data) > 3_000_000 or hashlib.sha256(data).hexdigest() != SHA:
        raise ValueError('Registry archive digest mismatch')
    files = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        for m in archive:
            p = PurePosixPath(m.name)
            if p.is_absolute() or '..' in p.parts or len(p.parts) < 2 or p.parts[0] != 'glib-0.18.5' or '\\' in m.name:
                raise ValueError('Unexpected archive path')
            if m.isdir():
                continue
            if not m.isfile() or m.size > 3_000_000:
                raise ValueError('Unexpected archive member')
            name = '/'.join(p.parts[1:])
            if name in files:
                raise ValueError('Duplicate archive member')
            with archive.extractfile(m) as f:
                files[name] = f.read()
    if len(files) != 121 or sum(map(len, files.values())) != 1717584:
        raise ValueError('Archive inventory mismatch')
    original = files[PATCH_FILE]
    old = b'let p: *mut libc::c_char = std::ptr::null_mut();'
    new = b'let mut p: *mut libc::c_char = std::ptr::null_mut();'
    old_arg = b'                &p,\n                std::ptr::null::<i8>(),'
    new_arg = b'                &mut p,\n                std::ptr::null::<i8>(),'
    if original.count(old) != 1 or original.count(old_arg) != 1:
        raise ValueError('Upstream patch context mismatch')
    files[PATCH_FILE] = original.replace(old, new, 1).replace(old_arg, new_arg, 1)
    return files

def verify(root, expected):
    actual = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*') if p.is_file()}
    if set(actual) != set(expected):
        raise ValueError('Vendor file set differs: '+str(sorted(set(actual)^set(expected))))
    for name, data in expected.items():
        if actual[name] != data:
            raise ValueError('Unexpected vendor content: '+name)
    print(f'Verified {len(actual)} vendor files; only upstream PR 1343 changes are present')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--provision', action='store_true')
    args = parser.parse_args()
    expected = expected_files()
    if args.provision:
        ROOT.mkdir(parents=True, exist_ok=False)
        for name, data in expected.items():
            path = ROOT / name
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('xb') as out:
                out.write(data)
    verify(ROOT, expected)

if __name__ == '__main__':
    main()
