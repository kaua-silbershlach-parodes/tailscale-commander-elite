import json
from pathlib import Path
import tempfile
import unittest
from release_preflight import validate

class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.r = Path(self.temp.name)
        (self.r/'src-tauri').mkdir()
        (self.r/'backend').mkdir()
        self.put('SECURITY_AUDIT.md','Release authorization: APPROVED\n')
        self.put('BOOK_CHECKLIST.md','- [ ] 1. Book 1 (release verification pending)\n  - [x] Pre-signing assessment complete\n')
        self.put('src-tauri/tauri.conf.json',json.dumps({'version':'1.2.2'}))
        self.put('src-tauri/Cargo.toml','[package]\nversion = "1.2.2"\n')
        self.put('backend/mix.exs','    version: "1.2.2",\n')
    def put(self,name,content):
        (self.r/name).write_text(content,encoding='utf-8')
    def test_valid(self):
        self.assertEqual(validate(self.r,'v1.2.2'),'1.2.2')
    def test_pending(self):
        self.put('SECURITY_AUDIT.md','Release authorization: PENDING\n')
        with self.assertRaisesRegex(ValueError,'authorization'):
            validate(self.r)
    def test_conflicting_approval(self):
        self.put('SECURITY_AUDIT.md','Release authorization: APPROVED\nRelease authorization: PENDING\n')
        with self.assertRaisesRegex(ValueError,'ambiguous'):
            validate(self.r)
    def test_missing_assessment(self):
        self.put('BOOK_CHECKLIST.md','- [ ] 1. Book 1 (open)\n')
        with self.assertRaisesRegex(ValueError,'assessment'):
            validate(self.r)
    def test_pending_assessment(self):
        self.put('BOOK_CHECKLIST.md','- [ ] 1. Book 1 (open)\n  - [ ] Pre-signing assessment complete\n')
        with self.assertRaisesRegex(ValueError,'assessment'):
            validate(self.r)
    def test_duplicate_assessment(self):
        self.put('BOOK_CHECKLIST.md','- [ ] 1. Book 1 (open)\n  - [x] Pre-signing assessment complete\n  - [ ] Pre-signing assessment complete\n')
        with self.assertRaisesRegex(ValueError,'assessment'):
            validate(self.r)
    def test_conflicting_book(self):
        self.put('BOOK_CHECKLIST.md','- [x] 1. Book 1 (done)\n- [ ] 1. Book 1 (open)\n')
        with self.assertRaisesRegex(ValueError,'Book 1'):
            validate(self.r)
    def test_mismatched_tag(self):
        with self.assertRaisesRegex(ValueError,'tag'):
            validate(self.r,'v1.2.1')
    def test_cargo_mismatch(self):
        self.put('src-tauri/Cargo.toml','[package]\nversion = "1.2.1"\n')
        with self.assertRaisesRegex(ValueError,'Cargo'):
            validate(self.r)
    def test_mix_mismatch(self):
        self.put('backend/mix.exs','    version: "1.2.1",\n')
        with self.assertRaisesRegex(ValueError,'Mix'):
            validate(self.r)

if __name__ == '__main__':
    unittest.main()
