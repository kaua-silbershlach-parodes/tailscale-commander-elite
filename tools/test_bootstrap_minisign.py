import base64
import hashlib
import io
import tarfile
import unittest
from unittest.mock import patch
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
import bootstrap_minisign as b

class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.key = Ed25519PrivateKey.generate()
        self.kid = b'fixture1'
        pub = self.key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        mock = patch.object(b, 'KEY', base64.b64encode(b'Ed'+self.kid+pub).decode())
        mock.start()
        self.addCleanup(mock.stop)
    def signature(self, data):
        sig = self.key.sign(hashlib.blake2b(data, digest_size=64).digest())
        comment = b'timestamp:1\tfile:fixture.tar.gz'
        return b'\n'.join([b'untrusted comment: fixture',base64.b64encode(b'ED'+self.kid+sig),b'trusted comment: '+comment,base64.b64encode(self.key.sign(sig+comment))])+b'\n'
    def test_signed_archive(self):
        b.authenticate(b'fixture', self.signature(b'fixture'))
    def test_modified_archive(self):
        with self.assertRaises(InvalidSignature):
            b.authenticate(b'changed',self.signature(b'fixture'))
    def test_modified_comment(self):
        sig = self.signature(b'fixture').replace(b'timestamp:1', b'timestamp:2')
        with self.assertRaises(InvalidSignature):
            b.authenticate(b'fixture',sig)
    def test_wrong_key_id(self):
        lines = self.signature(b'fixture').splitlines()
        raw = base64.b64decode(lines[1])
        lines[1] = base64.b64encode(raw[:2]+b'wrongkey'+raw[10:])
        with self.assertRaises(ValueError):
            b.authenticate(b'fixture',b'\n'.join(lines))
    def test_select_only_x86_64(self):
        binary = bytearray(64)
        binary[:6] = b'\x7fELF\x02\x01'
        binary[16:20] = b'\x03\x00\x3e\x00'
        out = io.BytesIO()
        with tarfile.open(fileobj=out,mode='w:gz') as a:
            for name, data in [('minisign-linux/x86_64/minisign',bytes(binary)),('../outside',b'ignored'),('other/minisign',b'\0'*64)]:
                m = tarfile.TarInfo(name)
                m.size = len(data)
                a.addfile(m, io.BytesIO(data))
        self.assertEqual(b.executable(out.getvalue()),('minisign-linux/x86_64/minisign',bytes(binary)))
    def test_reject_non_elf(self):
        out = io.BytesIO()
        with tarfile.open(fileobj=out,mode='w:gz') as a:
            m=tarfile.TarInfo('minisign'); m.size=64
            a.addfile(m,io.BytesIO(b'\0'*64))
        with self.assertRaises(ValueError):
            b.executable(out.getvalue())

if __name__ == '__main__':
    unittest.main()
