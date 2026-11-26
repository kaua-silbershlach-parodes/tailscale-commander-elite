#!/usr/bin/env python3
"""Verify release artifact bytes with the pinned Tauri public key and minisign.
Requires a trusted minisign executable on PATH. Never executes an artifact.
"""
import argparse
import base64
import binascii
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import urllib.request

REPO = 'kaua-silbershlach-parodes/tailscale-commander-elite'
ROOT = pathlib.Path(__file__).resolve().parents[1]
API = f'https://api.github.com/repos/{REPO}/releases/latest'
PREFIX = f'https://github.com/{REPO}/releases/download/'
MAX_ARTIFACT = 512 * 1024 * 1024
VERSION = re.compile(r'[0-9]+\.[0-9]+\.[0-9]+\Z')


def envelope(value, kind):
    raw = value.strip()
    if not raw.startswith('untrusted comment:'):
        try:
            raw = base64.b64decode(raw, validate=True).decode('ascii').strip()
        except (ValueError, UnicodeError, binascii.Error) as exc:
            raise ValueError(f'invalid {kind} encoding') from exc
    lines = raw.splitlines()
    expected = 2 if kind == 'key' else 4
    if len(lines) != expected or not lines[0].startswith('untrusted comment:'):
        raise ValueError(f'invalid {kind} envelope')
    base64.b64decode(lines[1], validate=True)
    if kind == 'signature':
        if not lines[2].startswith('trusted comment:'):
            raise ValueError('missing trusted comment')
        base64.b64decode(lines[3], validate=True)
    return '\n'.join(lines) + '\n'


def validate_signed_metadata(sig, artifact_name, expected_version):
    fields = {}
    prefix = 'trusted comment: '
    line = sig.splitlines()[2]
    if not line.startswith(prefix):
        raise ValueError('Invalid signed comment')
    for item in line[len(prefix):].split('	'):
        key, sep, value = item.partition(':')
        if not sep or not value or key in fields:
            raise ValueError('Malformed or duplicate signed metadata')
        fields[key] = value
    if not VERSION.fullmatch(expected_version) or fields.get('version') != expected_version:
        raise ValueError('Signed version does not match expected version')
    if not fields.get('timestamp', '').isdigit():
        raise ValueError('Missing signed timestamp')
    # GitHub changes spaces in the uploaded asset name to dots.
    if fields.get('file', '').replace(' ', '.') != artifact_name.replace(' ', '.'):
        raise ValueError('Signed file name mismatch')


def verify(artifact, signature, config, expected_version=None):
    artifact = pathlib.Path(artifact).resolve(strict=True)
    config = pathlib.Path(config)
    conf = strict_json(config.read_text(encoding='utf-8-sig'))
    key = envelope(conf['plugins']['updater']['pubkey'], 'key')
    sig = envelope(signature, 'signature')
    binary = shutil.which('minisign')
    if not binary:
        raise RuntimeError('trusted minisign executable required on PATH')
    with tempfile.TemporaryDirectory() as directory:
        sigfile = pathlib.Path(directory) / 'artifact.minisig'
        sigfile.write_text(sig, encoding='ascii')
        subprocess.run([binary, '-Vm', str(artifact), '-P', key.splitlines()[1], '-x', str(sigfile)], check=True, timeout=120)
    validate_signed_metadata(sig, artifact.name, expected_version if expected_version is not None else conf['version'])


def fetch(url, target, limit, expected_digest=None):
    request = urllib.request.Request(url, headers={'User-Agent': 'TCE-release-audit', 'Accept': 'application/octet-stream'})
    h = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(request, timeout=45) as response, open(target, 'wb') as out:
        if not response.geturl().startswith('https://'):
            raise ValueError('non-HTTPS redirect')
        while block := response.read(65536):
            size += len(block)
            if size > limit:
                raise ValueError('download exceeds bound')
            h.update(block)
            out.write(block)
    if expected_digest and expected_digest != 'sha256:' + h.hexdigest():
        raise ValueError('release digest mismatch')
    return size


def names(version):
    if not VERSION.fullmatch(version):
        raise ValueError('invalid release version')
    prefix = f'Tailscale.Commander.Elite_{version}'
    return (prefix + '_x64-setup.exe', prefix + '_amd64.AppImage', prefix + '_amd64.deb')


def validate_feed(feed, version):
    windows, appimage, deb = names(version)
    if feed.get('version') != version:
        raise ValueError('manifest and release tag differ')
    base = PREFIX + 'v' + version + '/'
    platforms = feed['platforms']
    for platform, allowed in [('windows-x86_64', [windows]), ('linux-x86_64', [appimage, deb])]:
        entry = platforms[platform]
        if entry['url'] not in [base + n for n in allowed]:
            raise ValueError('unexpected platform URL')
        envelope(entry['signature'], 'signature')
    return platforms


def strict_json(raw):
    def no_duplicates(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=no_duplicates)


def audit(config):
    with tempfile.TemporaryDirectory() as directory:
        d = pathlib.Path(directory)
        req = urllib.request.Request(API, headers={'User-Agent': 'TCE-release-audit', 'Accept': 'application/vnd.github+json'})
        with urllib.request.urlopen(req, timeout=45) as response:
            raw = response.read(2_000_001)
        if len(raw) > 2_000_000:
            raise ValueError('release metadata too large')
        release = strict_json(raw)
        tag = release['tag_name']
        if not tag.startswith('v') or release.get('draft') or release.get('prerelease'):
            raise ValueError('unexpected release state')
        version = tag[1:]
        artifacts = names(version)
        assets = {a['name']: a for a in release['assets']}
        if len(assets) != len(release['assets']):
            raise ValueError('duplicate release asset name')
        base = PREFIX + tag + '/'
        for name in ['latest.json', *artifacts, *(a + '.sig' for a in artifacts)]:
            entry = assets[name]
            if entry['browser_download_url'] != base + name:
                raise ValueError('unexpected asset URL')
            path = d / name
            limit = 1_000_000 if name.endswith(('.json', '.sig')) else MAX_ARTIFACT
            digest = entry.get('digest')
            if not isinstance(digest, str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
                raise ValueError('missing or invalid release asset digest')
            size = fetch(entry['browser_download_url'], path, limit, digest)
            if size != entry['size']:
                raise ValueError('release asset size mismatch')
        feed = strict_json((d / 'latest.json').read_text(encoding='utf-8'))
        platforms = validate_feed(feed, version)
        for name in artifacts:
            verify(d / name, (d / (name + '.sig')).read_text(encoding='ascii'), config, version)
        for entry in [platforms['windows-x86_64'], platforms['linux-x86_64']]:
            name = entry['url'].rsplit('/', 1)[1]
            verify(d / name, entry['signature'], config, version)
        print(f'Cryptographic release audit OK: {tag}; three artifacts and both feed entries')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=pathlib.Path, default=ROOT / 'src-tauri' / 'tauri.conf.json')
    sub = parser.add_subparsers(dest='command', required=True)
    local = sub.add_parser('artifact')
    local.add_argument('file', type=pathlib.Path)
    local.add_argument('signature', type=pathlib.Path)
    sub.add_parser('latest')
    args = parser.parse_args()
    if args.command == 'artifact':
        verify(args.file, args.signature.read_text(encoding='ascii'), args.config)
    else:
        audit(args.config)


if __name__ == '__main__':
    main()
