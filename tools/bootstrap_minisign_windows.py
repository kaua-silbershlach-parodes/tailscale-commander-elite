#!/usr/bin/env python3
"""Provision the previously authenticated upstream Windows x64 verifier.

The exact archive and PE hashes were independently authenticated with the
pinned upstream Ed25519 key. Recheck both hashes before ever executing
the binary, then verify the archive's upstream signature with it.
"""
import argparse
import hashlib
import io
from pathlib import Path
import struct
import subprocess
import tempfile
import urllib.request
import zipfile

URL = 'https://github.com/jedisct1/minisign/releases/download/0.12/minisign-0.12-win64.zip'
KEY = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
ARCHIVE_SHA = '37b600344e20c19314b2e82813db2bfdcc408b77b876f7727889dbd46d539479'
BINARY_SHA = '5535be9e4e123831ebe6ef324aafe9dde507015c176191f9e20c3ad60567f9e1'
MEMBER = 'minisign-win64/x86_64/minisign.exe'


def download(url, size):
    req = urllib.request.Request(url, headers={'User-Agent':'TCE-windows-verifier'})
    with urllib.request.urlopen(req, timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        data = response.read(size + 1)
    if len(data) != size:
        raise ValueError('Unexpected download size')
    return data


def extract(data):
    if len(data) != 252505 or hashlib.sha256(data).hexdigest() != ARCHIVE_SHA:
        raise ValueError('Archive digest or size mismatch')
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        members = [m for m in z.infolist() if m.filename == MEMBER]
        if len(members) != 1 or members[0].is_dir() or members[0].file_size != 285696:
            raise ValueError('Unexpected archive member')
        binary = z.read(members[0])
    if len(binary) != 285696 or hashlib.sha256(binary).hexdigest() != BINARY_SHA:
        raise ValueError('Executable digest or size mismatch')
    off = struct.unpack_from('<I', binary, 60)[0]
    if (binary[:2] != b'MZ' or off > len(binary)-26 or
        binary[off:off+4] != b'PE\0\0' or binary[off+4:off+6] != b'\x64\x86' or
        binary[off+24:off+26] != b'\x0b\x02'):
        raise ValueError('Not a Windows x64 PE32+ executable')
    return binary


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--bin-dir', type=Path, required=True)
    args = p.parse_args()
    data = download(URL, 252505)
    sig = download(URL+'.minisig', 318)
    binary = extract(data)
    # Verify with the digest-pinned binary, not with an unverified download.
    # Keep the final PATH directory absent until the signature passes.
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        verifier = root/'minisign.exe'
        verifier.write_bytes(binary)
        archive = root/'minisign-0.12-win64.zip'
        archive.write_bytes(data)
        signature = root/'minisign-0.12-win64.zip.minisig'
        signature.write_bytes(sig)
        subprocess.run([str(verifier), '-Vm', str(archive), '-P', KEY,
                        '-x', str(signature)], check=True, timeout=30)
    args.bin_dir.mkdir(parents=True, exist_ok=False)
    with (args.bin_dir/'minisign.exe').open('xb') as out:
        out.write(binary)
    print('Authenticated Windows x64 minisign 0.12:', BINARY_SHA)


if __name__ == '__main__':
    main()
