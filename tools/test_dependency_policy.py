import copy
from datetime import date
import unittest
import dependency_policy as p

class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.today=date(2026,11,27)
        self.report={'settings':{'ignore':[],'target_arch':[],'target_os':[],
            'severity':None,'informational_warnings':['notice','unmaintained','unsound']},
            'database':{'advisory-count':1000,'last-commit':'abc'},
            'lockfile':{'dependency-count':100},
            'vulnerabilities':{'found':False,'count':0,'list':[]},
            'warnings':{'unmaintained':[{'kind':'unmaintained','denied':True,
                'package':{'name':name,'version':version},
                'advisory':{'id':identifier,'package':name,'informational':'unmaintained'}}
                for identifier,(name,version) in p.APPROVED.items()]}}
    def check(self,code=1):
        return p.evaluate(self.report,code,self.today)
    def test_exact_approved(self):
        self.assertEqual(self.check(),sorted(p.APPROVED))
    def test_clean(self):
        self.report['warnings']={}
        self.assertEqual(self.check(0),[])
    def test_known_vulnerability(self):
        self.report['vulnerabilities']={'found':True,'count':1,'list':[{'advisory':{'id':next(iter(p.APPROVED))}}]}
        with self.assertRaisesRegex(ValueError,'Known vulnerabilities'): self.check()
    def test_new_warning(self):
        self.report['warnings']['unmaintained'][0]['advisory']['id']='RUSTSEC-2099-9999'
        with self.assertRaises(ValueError): self.check()
    def test_changed_version(self):
        self.report['warnings']['unmaintained'][0]['package']['version']='9.9.9'
        with self.assertRaises(ValueError): self.check()
    def test_expired(self):
        self.today=p.EXPIRES
        with self.assertRaisesRegex(ValueError,'expired'): self.check()
    def test_unsound(self):
        self.report['warnings']['unsound']=[{'kind':'unsound'}]
        with self.assertRaises(ValueError): self.check()
    def test_yanked(self):
        self.report['warnings']['yanked']=[{'kind':'yanked'}]
        with self.assertRaises(ValueError): self.check()
    def test_notice(self):
        self.report['warnings']['notice']=[{'kind':'notice'}]
        with self.assertRaises(ValueError): self.check()
    def test_filtered(self):
        self.report['settings']['ignore']=list(p.APPROVED)
        with self.assertRaises(ValueError): self.check()
    def test_scan_error(self):
        with self.assertRaises(ValueError): self.check(2)
    def test_inconsistent_exit(self):
        with self.assertRaises(ValueError): self.check(0)
    def test_duplicate(self):
        self.report['warnings']['unmaintained'].append(copy.deepcopy(self.report['warnings']['unmaintained'][0]))
        with self.assertRaises(ValueError): self.check()
    def test_reclassified(self):
        self.report['warnings']['unmaintained'][0]['advisory']['informational']='unsound'
        with self.assertRaises(ValueError): self.check()
    def test_missing_report(self):
        self.report.pop('warnings')
        with self.assertRaises(KeyError): self.check()

if __name__=='__main__': unittest.main()


class LockPackageCountTests(unittest.TestCase):
    def test_canonical_headers(self):
        self.assertEqual(p.lock_package_count(b'version = 4\n[[package]]\nname = "a"\n[[package]]\nname = "b"\n'), 2)

    def test_crlf(self):
        self.assertEqual(p.lock_package_count(b'[[package]]\r\nname = "a"\r\n'), 1)

    def test_empty_rejected(self):
        with self.assertRaises(ValueError):
            p.lock_package_count(b'version = 4\n')
