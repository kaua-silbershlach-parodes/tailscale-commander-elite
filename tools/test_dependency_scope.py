import copy
import unittest
import dependency_scope as s

class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.report = {
            s.TARGETS[0]: {'active': {'chrono': [], 'proc-macro-error': [], 'glib': []}},
            s.TARGETS[1]: {'active': {'chrono': [], 'proc-macro-error': ['1.0.4'], 'glib': ['0.18.5']},
                           'macro_parents': {'glib-macros': ['proc-macro', 'test'], 'gtk3-macros': ['proc-macro']}},
        }
    def test_parser(self):
        t = 'app v1.2.2\nchrono v0.4.45\nchrono v0.4.45 (*)\nproc-macro-error v1.0.4\nproc-macro-error-attr v1.0.4\n'
        self.assertEqual(s.active_packages(t), {'chrono': ['0.4.45'], 'proc-macro-error': ['1.0.4'], 'glib': []})
    def test_current_scope(self):
        s.check_scope(self.report)
    def test_chrono_activation(self):
        for target in s.TARGETS:
            report = copy.deepcopy(self.report)
            report[target]['active']['chrono'] = ['0.4.45']
            with self.assertRaisesRegex(ValueError, 'Chrono'):
                s.check_scope(report)
    def test_windows_macro_activation(self):
        self.report[s.TARGETS[0]]['active']['proc-macro-error'] = ['1.0.4']
        with self.assertRaisesRegex(ValueError, 'Windows'):
            s.check_scope(self.report)
    def test_non_macro_parent(self):
        self.report[s.TARGETS[1]]['macro_parents']['gtk3-macros'] = ['lib']
        with self.assertRaisesRegex(ValueError, 'macro-only'):
            s.check_scope(self.report)
    def test_unexpected_parent(self):
        self.report[s.TARGETS[1]]['macro_parents']['other'] = ['proc-macro']
        with self.assertRaisesRegex(ValueError, 'parents'):
            s.check_scope(self.report)

if __name__ == '__main__':
    unittest.main()
