#!/usr/bin/env python3
"""Provision an official, exact version of Tauri CLI without compiling it."""
import hashlib
import io
import os
from pathlib import Path, PurePosixPath
import platform
import subprocess
import tarfile
import urllib.request
import zipfile

VERSION = '2.12.6'
BASE = 'https://github.com/tauri-apps/tauri/releases/download/tauri-cli-v' + VERSION + '/'
PINS = {
    'Windows': ('cargo-tauri-x86_64-pc-windows-msvc.zip', 7939975,
                '39636fa68bc00f13dd610fb57688f292e93742978cc35395f2f1be7c540b88a1',
                'cargo-tauri.exe'),
    'Linux': ('cargo-tauri-x86_64-unknown-linux-gnu.tgz', 9229688,
              '057983293b14d88b29331f96b2e57ce9780f887e7a0b76e255844924f83118dc',
              'cargo-tauri'),
}
MAX_BINARY = 64 * 1024 * 1024


def safe_member(name):
    p = PurePosixPath(name)
    return not p.is_absolute() and '..' not in p.parts and '\\' not in name


def unpack(data, system):
    _, size, sha, exe = PINS[system]
    if len(data) != size or hashlib.sha256(data).hexdigest() != sha:
        raise ValueError('Official Tauri CLI archive integrity mismatch')
    if system == 'Windows':
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            found = [x for x in z.infolist() if not x.is_dir() and PurePosixPath(x.filename).name == exe]
            if len(found) != 1 or not safe_member(found[0].filename) or found[0].file_size > MAX_BINARY:
                raise ValueError('Unexpected CLI member')
            binary = z.read(found[0])
        if len(binary) != 16191488 or hashlib.sha256(binary).hexdigest() != '003cab86f2a4efabdbb76cff6bc58524f9d1a3f9647cda1e6bee6812eebbb574' or not binary.startswith(b'MZ'):
            raise ValueError('Windows executable integrity mismatch')
    else:
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
            found = [x for x in tar.getmembers() if PurePosixPath(x.name).name == exe]
            if len(found) != 1 or not found[0].isfile() or not safe_member(found[0].name) or found[0].size > MAX_BINARY:
                raise ValueError('Unexpected CLI member')
            with tar.extractfile(found[0]) as f:
                binary = f.read(MAX_BINARY + 1)
        if len(binary) > MAX_BINARY or not binary.startswith(b'\x7fELF'):
            raise ValueError('Invalid Linux executable')
    return binary


def main():
    # Each invocation is on a fresh hosted runner; no signing material required.
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise RuntimeError('CI provisioning requires a GitHub-hosted runner')
    system = platform.system()
    if system not in PINS or platform.machine().lower() not in ('x86_64', 'amd64'):
        raise RuntimeError('Unsupported CLI platform')
    name, size, _, exe = PINS[system]
    with urllib.request.urlopen(urllib.request.Request(BASE + name, headers={'User-Agent':'TCE-verified-cli'}), timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        data = response.read(size + 1)
    binary = unpack(data, system)
    folder = Path(os.environ['RUNNER_TEMP']) / 'tce-tauri-cli'
    folder.mkdir(exist_ok=False)
    target = folder / exe
    with target.open('xb') as out:
        out.write(binary)
    if system == 'Linux':
        target.chmod(0o700)
    result = subprocess.check_output([str(target), 'tauri', '--version'], text=True, timeout=30).strip()
    if result != 'tauri-cli ' + VERSION:
        raise ValueError('Unexpected CLI version')
    with Path(os.environ['GITHUB_PATH']).open('a', encoding='utf-8') as f:
        f.write(str(folder.resolve()) + '\n')
    print('Verified official ' + result)


if __name__ == '__main__':
    main()
