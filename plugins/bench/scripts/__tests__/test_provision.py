import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import provision  # noqa: E402


class TestBranchName(unittest.TestCase):
    def test_always_prefixed_with_bench(self):
        name = provision.branch_name("NA-68", "opus", "r1")
        self.assertTrue(name.startswith("bench/"))
        self.assertEqual(name, "bench/NA-68/opus/r1")


class TestAssertBenchBranch(unittest.TestCase):
    def test_accepts_bench_branch(self):
        provision.assert_bench_branch("bench/NA-68/opus/r1")

    def test_rejects_develop(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("develop")

    def test_rejects_main(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("main")

    def test_rejects_lookalike_prefix(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("benchmarks/NA-68")

    def test_rejects_traversal(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/../develop")


if __name__ == "__main__":
    unittest.main()
