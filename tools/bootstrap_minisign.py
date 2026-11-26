#!/usr/bin/env python3
"""Fetch and authenticate upstream minisign 0.12 for Linux x86_64.
Never extract arbitrary archive paths; install only the authenticated ELF.
"""
import argparse
import base64
import hashlib
import io
import os
import pathlib
import tarfile
import urllib.request

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

URL = 'https://github.com/jedisct1/minisign/releases/download/0.12/minisign-0.12-linux.tar.gz'
KEY = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'

def download(url, limit):
    request = urllib.request.Request(url, headers={'User-Agent': 'TCE-ci-verifier'})
    with urllib.request.urlopen(request, timeout=60) as response:
        if not response.geturl().startswith('https://'):
            raise ValueError('Non-HTTPS redirect')
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Oversized download')
    return data

def authenticate(data, signature):
    lines = signature.decode('ascii').splitlines()
    if len(lines) != 4 or not lines[0].startswith('untrusted comment: ') or not lines[2].startswith('trusted comment: '):
        raise ValueError('Invalid signature envelope')
    pk = base64.b64decode(KEY, validate=True)
    sig = base64.b64decode(lines[1], validate=True)
    global_sig = base64.b64decode(lines[3], validate=True)
    if len(pk) != 42 or pk[:2] != b'Ed' or len(sig) != 74 or sig[:2] != b'ED' or sig[2:10] != pk[2:10] or len(global_sig) != 64:
        raise ValueError('Invalid algorithm, length or signing key')
    key = Ed25519PublicKey.from_public_bytes(pk[10:])
    key.verify(sig[10:], hashlib.blake2b(data, digest_size=64).digest())
    key.verify(global_sig, sig[10:] + lines[2][len('trusted comment: '):].encode('ascii'))

def executable(data):
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        candidates = []
        for member in archive:
            if not member.isfile() or pathlib.PurePosixPath(member.name).name != 'minisign':
                continue
            if member.size < 64 or member.size > 2_000_000:
                raise ValueError('Unexpected executable size')
            with archive.extractfile(member) as source:
                binary = source.read()
            # ELF64, little-endian, EM_X86_64, ET_EXEC or ET_DYN.
            if binary[:6] == b'\x7fELF\x02\x01' and binary[18:20] == b'\x3e\x00' and binary[16:18] in (b'\x02\x00', b'\x03\x00'):
                candidates.append((member.name, binary))
        if len(candidates) != 1:
            raise ValueError('Expected one Linux x86_64 minisign executable')
        return candidates[0]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bin-dir', type=pathlib.Path)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    if not args.verify_only and args.bin_dir is None:
        parser.error('--bin-dir required unless --verify-only')
    data = download(URL, 400_000)
    sig = download(URL + '.minisig', 2_000)
    if len(data) != 271043 or len(sig) != 321:
        raise ValueError('Unexpected release asset lengths')
    authenticate(data, sig)
    if hashlib.sha256(data).hexdigest() != '9a599b48ba6eb7b1e80f12f36b94ceca7c00b7a5173c95c3efc88d9822957e73':
        raise ValueError('Pinned archive digest mismatch')
    name, binary = executable(data)
    if name != 'minisign-linux/x86_64/minisign' or hashlib.sha256(binary).hexdigest() != '2c74dffcc1c9a5ee55957c60971998ace2b89f22585631594ec2152c588af8db':
        raise ValueError('Pinned executable identity mismatch')
    print('Authenticated upstream archive SHA256:', hashlib.sha256(data).hexdigest())
    print('Authenticated member:', name, 'SHA256:', hashlib.sha256(binary).hexdigest())
    if not args.verify_only:
        args.bin_dir.mkdir(parents=True, exist_ok=False)
        target = args.bin_dir / 'minisign'
        with target.open('xb') as out:
            out.write(binary)
        os.chmod(target, 0o755)

if __name__ == '__main__':
    main()
