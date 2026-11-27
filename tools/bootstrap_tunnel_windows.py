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


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--bin-dir', type=Path, required=True)
    provision(parser.parse_args().bin_dir)
