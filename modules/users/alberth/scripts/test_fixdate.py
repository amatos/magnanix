#!/usr/bin/env python3
# Tests for fixdate.py.  Run with:
#   python3 -I test_fixdate.py [path/to/fixdate.py]
#
# The macOS calls (getattrlist/setattrlist/getxattr) are patched out, so these
# run on Linux too; one smoke test talks to the real filesystem on macOS.

import argparse
import datetime as dt
import errno
import importlib.util
import io
import os
import plistlib
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = sys.argv.pop(1) if len(sys.argv) > 1 else os.path.join(HERE, "fixdate.py")

spec = importlib.util.spec_from_file_location("fixdate", SCRIPT)
fd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fd)

CUTOFF = dt.datetime(1990, 1, 1).timestamp()
BOGUS = dt.datetime(1984, 1, 24).timestamp()
GOOD = dt.datetime(2024, 5, 6, 7, 8, 9).timestamp()


def touch(path, mtime=GOOD):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w"):
        pass
    os.utime(path, (mtime, mtime))


class ParseDownloadedDate(unittest.TestCase):
    def test_binary_list_returns_earliest(self):
        a = dt.datetime(2024, 1, 2, 3, 4, 5)
        b = dt.datetime(2023, 1, 2, 3, 4, 5)
        raw = plistlib.dumps([a, b], fmt=plistlib.FMT_BINARY)
        expected = b.replace(tzinfo=fd.UTC).timestamp()
        self.assertEqual(fd.parse_downloaded_date(raw), expected)

    def test_xml_single_date(self):
        a = dt.datetime(2024, 1, 2, 3, 4, 5)
        raw = plistlib.dumps(a)
        expected = a.replace(tzinfo=fd.UTC).timestamp()
        self.assertEqual(fd.parse_downloaded_date(raw), expected)

    def test_garbage_and_non_dates(self):
        self.assertIsNone(fd.parse_downloaded_date(b"not a plist"))
        self.assertIsNone(fd.parse_downloaded_date(b"bplist00garbage"))
        self.assertIsNone(fd.parse_downloaded_date(b"<?xml version='1.0'?><plist"))
        self.assertIsNone(fd.parse_downloaded_date(plistlib.dumps(["text"])))


class ParseDay(unittest.TestCase):
    def test_local_midnight(self):
        self.assertEqual(fd.parse_day("2026-11-12"), dt.datetime(2026, 11, 12))

    def test_invalid(self):
        with self.assertRaises(argparse.ArgumentTypeError):
            fd.parse_day("2026-13-01")

    def test_day_window_is_one_local_day(self):
        start, end = fd.day_window(dt.datetime(2026, 11, 12))
        self.assertEqual(start, dt.datetime(2026, 11, 12).timestamp())
        self.assertEqual(end, dt.datetime(2026, 11, 13).timestamp())


class IterItems(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        touch(os.path.join(self.root, "a.txt"))
        touch(os.path.join(self.root, "sub", "b.txt"))
        touch(os.path.join(self.root, "Foo.APP", "Contents", "Info.plist"))
        self.errors = []

    def tearDown(self):
        self.tmp.cleanup()

    def items(self, roots, into_packages=False):
        return set(fd.iter_items(roots, into_packages, True, self.errors.append))

    def rel(self, paths):
        return {os.path.relpath(p, self.root) for p in paths}

    def test_skips_package_contents_case_insensitively(self):
        self.assertEqual(
            self.rel(self.items([self.root])),
            {".", "a.txt", "sub", "sub/b.txt", "Foo.APP"},
        )

    def test_into_packages(self):
        self.assertIn(
            "Foo.APP/Contents/Info.plist",
            self.rel(self.items([self.root], into_packages=True)),
        )

    def test_package_given_as_root_is_one_item(self):
        pkg = os.path.join(self.root, "Foo.APP")
        self.assertEqual(self.items([pkg]), {pkg})

    def test_missing_root_reported_and_others_scanned(self):
        missing = os.path.join(self.root, "nope")
        found = self.items([missing, os.path.join(self.root, "sub")])
        self.assertEqual(self.rel(found), {"sub", "sub/b.txt"})
        self.assertEqual(len(self.errors), 1)
        self.assertEqual(self.errors[0].errno, errno.ENOENT)


class ChooseReplacement(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name, "f")
        touch(self.path, mtime=GOOD)
        self.now = GOOD + 1000

    def tearDown(self):
        self.tmp.cleanup()

    def choose(self, downloaded, birth, windows=()):
        st = mock.Mock(st_mtime=GOOD, st_birthtime=birth)
        with (
            mock.patch.object(fd, "get_downloaded_time", return_value=downloaded),
            mock.patch.object(fd.os, "lstat", return_value=st),
        ):
            return fd.choose_replacement(self.path, CUTOFF, self.now, windows)

    def test_prefers_download_date(self):
        self.assertEqual(self.choose(GOOD - 5, GOOD - 9), (GOOD - 5, "downloaded"))

    def test_falls_back_to_birth_then_mtime(self):
        self.assertEqual(self.choose(None, GOOD - 9), (GOOD - 9, "created"))
        self.assertEqual(self.choose(None, BOGUS), (GOOD, "modified"))

    def test_rejects_future_and_bad_windows(self):
        future = self.now + 2 * fd.FUTURE_SLACK
        self.assertEqual(self.choose(future, None), (GOOD, "modified"))
        self.assertEqual(
            self.choose(None, None, windows=[(GOOD - 1, GOOD + 1)]), (None, None)
        )


class Run(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.bad = os.path.join(self.root, "bad.txt")
        self.ok = os.path.join(self.root, "ok.txt")
        touch(self.bad)
        touch(self.ok)
        self.added = {self.root: GOOD, self.bad: BOGUS, self.ok: GOOD}
        self.set_calls = []
        self.set_error = None
        patches = [
            mock.patch.object(fd, "get_added_time", side_effect=self.added.get),
            mock.patch.object(fd, "set_added_time", side_effect=self.fake_set),
            mock.patch.object(fd, "get_downloaded_time", return_value=None),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def fake_set(self, path, ts):
        if self.set_error:
            raise OSError(self.set_error, os.strerror(self.set_error), path)
        self.set_calls.append((path, ts))

    def run_fd(self, roots=None, **kw):
        out, err = io.StringIO(), io.StringIO()
        stats = fd.run(roots or [self.root], CUTOFF, out=out, err=err, **kw)
        return stats, out.getvalue(), err.getvalue()

    def test_dry_run_changes_nothing(self):
        stats, out, _ = self.run_fd()
        self.assertEqual((stats["scanned"], stats["bad"]), (3, 1))
        self.assertEqual(self.set_calls, [])
        self.assertIn(f"WOULD  {self.bad}", out)
        self.assertIn("No usable date 0, errors 0.", out)

    def test_apply_writes(self):
        stats, out, _ = self.run_fd(apply=True)
        self.assertEqual(stats["fixed"], 1)
        self.assertEqual(len(self.set_calls), 1)
        self.assertEqual(self.set_calls[0][0], self.bad)
        self.assertIn(f"FIX    {self.bad}", out)

    def test_bad_day_window_marks_items_bad(self):
        stats, out, _ = self.run_fd(windows=[(GOOD - 1, GOOD + 1)])
        self.assertEqual(stats["bad"], 3)
        # No replacement may come from inside the window.
        self.assertNotIn(f"-> {fd.fmt(GOOD)}", out)

    def test_denied_reported_with_reason_even_when_quiet(self):
        self.set_error = errno.EPERM
        stats, out, err = self.run_fd(apply=True, verbose=False)
        self.assertEqual(stats["denied"], 1)
        self.assertIn(f"DENIED {self.bad}", err)
        self.assertIn(os.strerror(errno.EPERM), err)
        self.assertNotIn("DENIED", out)

    def test_other_set_error_counted(self):
        self.set_error = errno.EIO
        stats, _, err = self.run_fd(apply=True)
        self.assertEqual(stats["errors"], 1)
        self.assertIn(f"ERROR  {self.bad}", err)

    def test_read_error_reported(self):
        def boom(path):
            raise OSError(errno.EIO, os.strerror(errno.EIO), path)

        with mock.patch.object(fd, "get_added_time", side_effect=boom):
            stats, _, err = self.run_fd([self.bad])
        self.assertEqual(stats["errors"], 1)
        self.assertIn(self.bad, err)

    def test_missing_root(self):
        stats, _, err = self.run_fd([os.path.join(self.root, "nope"), self.ok])
        self.assertEqual((stats["scanned"], stats["errors"]), (1, 1))
        self.assertIn("nope", err)


class Main(unittest.TestCase):
    def call(self, argv, platform="darwin"):
        with (
            mock.patch.object(fd.sys, "platform", platform),
            mock.patch.object(
                fd, "run", return_value={"errors": 0, "denied": 0}
            ) as run,
            mock.patch("sys.stderr", io.StringIO()),
        ):
            return fd.main(argv), run

    def test_passes_local_cutoff_and_windows(self):
        rc, run = self.call(["--cutoff", "2000-01-01", "--bad-date", "2026-11-12", "x"])
        self.assertEqual(rc, 0)
        kw = run.call_args.kwargs
        self.assertEqual(kw["cutoff"], dt.datetime(2000, 1, 1).timestamp())
        self.assertEqual(kw["windows"], [fd.day_window(dt.datetime(2026, 11, 12))])

    def test_default_cutoff(self):
        _, run = self.call(["x"])
        self.assertEqual(run.call_args.kwargs["cutoff"], CUTOFF)

    def test_bad_date_is_usage_error(self):
        with self.assertRaises(SystemExit) as cm:
            self.call(["--bad-date", "tomorrow", "x"])
        self.assertEqual(cm.exception.code, 2)

    def test_not_macos(self):
        with self.assertRaises(SystemExit) as cm:
            self.call(["x"], platform="linux")
        self.assertEqual(cm.exception.code, 2)

    def test_exit_code_on_failures(self):
        for stats in ({"errors": 1, "denied": 0}, {"errors": 0, "denied": 2}):
            with (
                mock.patch.object(fd.sys, "platform", "darwin"),
                mock.patch.object(fd, "run", return_value=stats),
            ):
                self.assertEqual(fd.main(["x"]), 1)


@unittest.skipUnless(sys.platform == "darwin", "macOS only")
class RealFilesystem(unittest.TestCase):
    def test_round_trip_added_time(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "f")
            touch(path)
            if fd.get_added_time(path) is None:
                self.skipTest("volume has no Date Added")
            fd.set_added_time(path, GOOD + 0.5)
            self.assertAlmostEqual(fd.get_added_time(path), GOOD + 0.5, places=3)
            self.assertIsNone(fd.get_downloaded_time(path))


if __name__ == "__main__":
    unittest.main()
