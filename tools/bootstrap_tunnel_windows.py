#!/usr/bin/env python3
"""Provision only the official pinned Windows x64 tunnel client. No secrets."""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import urllib.request
import zipfile

VERSION = '0.0.21'
URL = 'https://github.com/openai/tunnel-client/releases/download/v0.0.21/tunnel-client-v0.0.21-windows-amd64.zip'
ARCHIVE_SIZE = 29683613
ARCHIVE_SHA = '2faf80ae62b58485fcef534cd3f78cd8b82e71cb04d14c2a5c73dbb4eb6c575a'
EXE_SIZE = 26860544
EXE_SHA = 'e0b2f25d08f24a4ddb7a04f3d43b62f88d4b18a5b20f2e478295cd8f353f21e5'


def checked_executable(data):
    if len(data) != ARCHIVE_SIZE or hashlib.sha256(data).hexdigest() != ARCHIVE_SHA:
        raise ValueError('Official archive length or SHA-256 mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        candidates = [m for m in archive.infolist() if not m.is_dir()
                      and PurePosixPath(m.filename).name == 'tunnel-client.exe']
        if len(candidates) != 1 or candidates[0].file_size != EXE_SIZE:
            raise ValueError('Unexpected executable archive member')
        member = candidates[0]
        path = PurePosixPath(member.filename)
        if path.is_absolute() or '..' in path.parts or '\\' in member.filename:
            raise ValueError('Unexpected executable path')
        executable = archive.read(member)
    if len(executable) != EXE_SIZE or executable[:2] != b'MZ' or hashlib.sha256(executable).hexdigest() != EXE_SHA:
        raise ValueError('Tunnel executable failed integrity check')
    return executable


def provision(folder):
    destination = folder / 'tunnel-client.exe'
    if destination.exists():
        if destination.is_symlink() or destination.stat().st_size != EXE_SIZE or hashlib.sha256(destination.read_bytes()).hexdigest() != EXE_SHA:
            raise ValueError('Existing binary differs; refusing overwrite')
        print('Existing official tunnel client verified.')
        return
    request = urllib.request.Request(URL, headers={'User-Agent': 'TCE-tunnel-provision'})
    with urllib.request.urlopen(request, timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        data = response.read(ARCHIVE_SIZE + 1)
    executable = checked_executable(data)
    folder.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as out:
        out.write(executable)
    print('Official Windows tunnel client verified and provisioned; not executed.')


BUNDLE_NAMES = {
    'tunnel-client.exe', 'LICENSE', 'NOTICE',
    'tunnel-client-v0.0.21-windows-amd64-licenses.txt',
    'tunnel-client-v0.0.21-windows-amd64.spdx.json',
}

def provision_bundle(folder, archive_file=None):
    if archive_file is None:
        request = urllib.request.Request(URL, headers={'User-Agent': 'TCE-tunnel-provision'})
        with urllib.request.urlopen(request, timeout=60) as response:
            if not response.geturl().startswith('https://'):
                raise ValueError('Non-HTTPS redirect')
            data = response.read(ARCHIVE_SIZE + 1)
    else:
        if archive_file.stat().st_size != ARCHIVE_SIZE:
            raise ValueError('Unexpected archive size')
        data = archive_file.read_bytes()
    exe = checked_executable(data)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        selected = [m for m in archive.infolist() if m.filename in BUNDLE_NAMES and not m.is_dir()]
        if len(selected) != len(BUNDLE_NAMES) or {m.filename for m in selected} != BUNDLE_NAMES:
            raise ValueError('Unexpected official notice inventory')
        payloads = {}
        for member in selected:
            if member.filename != 'tunnel-client.exe' and member.file_size > 2*1024*1024:
                raise ValueError('Unexpected notice size')
            payloads[member.filename] = archive.read(member)
        if payloads['tunnel-client.exe'] != exe:
            raise ValueError('Executable mismatch')
    folder.mkdir(parents=True, exist_ok=True)
    if folder.is_symlink() or set(x.name for x in folder.iterdir()) - BUNDLE_NAMES:
        raise ValueError('Unexpected resource directory contents')
    for filename, raw in payloads.items():
        path = folder / filename
        if path.exists() or path.is_symlink():
            if path.is_symlink() or path.stat().st_size != len(raw) or path.read_bytes() != raw:
                raise ValueError('Existing resource differs; refusing overwrite')
        else:
            with path.open('xb') as out:
                out.write(raw)
    print('Official pinned tunnel-client and legal notices verified; not executed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bin-dir', type=Path, required=True)
    parser.add_argument('--bundle', action='store_true')
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    if args.bundle:
        provision_bundle(args.bin_dir, args.archive)
    elif args.archive is not None:
        parser.error('--archive requires --bundle')
    else:
        provision(args.bin_dir)
