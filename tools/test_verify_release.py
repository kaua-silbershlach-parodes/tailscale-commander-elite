"""Native minisign regression tests with ephemeral keys; never sign production assets."""
import base64
import hashlib
import json
import pathlib
import subprocess
import tempfile
import unittest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
import verify_release as v

def b64(b): return base64.b64encode(b).decode('ascii')

class SignedVersionTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=pathlib.Path(self.tmp.name)
        self.file=self.root/'Tailscale.Commander.Elite_1.2.2_x64-setup.exe'
        self.file.write_bytes(b'non executable test fixture')
        self.key=Ed25519PrivateKey.generate()
        self.kid=b'fixture1'
        pub=self.key.public_key().public_bytes(Encoding.Raw,PublicFormat.Raw)
        self.config=self.root/'config.json'
        self.config.write_text(json.dumps({'version':'1.2.2','plugins':{'updater':{'pubkey':'untrusted comment: fixture public key\n'+b64(b'Ed'+self.kid+pub)+'\n'}}}),encoding='utf-8')

    def sign(self, comment='timestamp:1\tfile:Tailscale Commander Elite_1.2.2_x64-setup.exe\tversion:1.2.2'):
        sig=self.key.sign(hashlib.blake2b(self.file.read_bytes(),digest_size=64).digest())
        glob=self.key.sign(sig+comment.encode('ascii'))
        return b64(('untrusted comment: fixture signature\n'+b64(b'ED'+self.kid+sig)+'\ntrusted comment: '+comment+'\n'+b64(glob)+'\n').encode('ascii'))

    def test_valid_signature(self):
        v.verify(self.file,self.sign(),self.config)
    def test_version_replay_rejected(self):
        with self.assertRaisesRegex(ValueError,'Signed version'):
            v.verify(self.file,self.sign(),self.config,'1.2.3')
    def test_missing_version_rejected(self):
        with self.assertRaisesRegex(ValueError,'Signed version'):
            v.verify(self.file,self.sign('timestamp:1\tfile:'+self.file.name),self.config)
    def test_wrong_signed_filename(self):
        with self.assertRaisesRegex(ValueError,'Signed file name'):
            v.verify(self.file,self.sign('timestamp:1\tfile:other.exe\tversion:1.2.2'),self.config)
    def test_duplicate_version_rejected(self):
        with self.assertRaisesRegex(ValueError,'duplicate'):
            v.verify(self.file,self.sign('timestamp:1\tfile:'+self.file.name+'\tversion:1.2.2\tversion:1.2.2'),self.config)
    def test_tamper_rejected(self):
        sig=self.sign()
        self.file.write_bytes(b'altered')
        with self.assertRaises(subprocess.CalledProcessError):
            v.verify(self.file,sig,self.config)
    def test_comment_tamper_rejected(self):
        raw=base64.b64decode(self.sign()).replace(b'version:1.2.2',b'version:1.2.3')
        with self.assertRaises(subprocess.CalledProcessError):
            v.verify(self.file,b64(raw),self.config,'1.2.3')

class ReleaseVersionTests(unittest.TestCase):
    def test_expected_published_version(self):
        self.assertEqual(v.validate_release_version('v1.2.2', '1.2.2'), '1.2.2')
    def test_old_published_release_rejected(self):
        with self.assertRaisesRegex(ValueError, 'expected version'):
            v.validate_release_version('v1.2.1', '1.2.2')
    def test_invalid_tag(self):
        with self.assertRaisesRegex(ValueError, 'invalid release tag'):
            v.validate_release_version('v1.2.2-preview')


if __name__=='__main__': unittest.main()
