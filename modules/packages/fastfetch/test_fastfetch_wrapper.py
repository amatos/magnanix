#!/usr/bin/env python3
# Tests for fastfetch-wrapper.py.  Run with:
#   python3 -I test_fastfetch_wrapper.py [path/to/fastfetch-wrapper.py]
#
# The end-to-end tests drive the wrapper against a fake `fastfetch` script
# whose behaviour is picked by the FAKE_MODE environment variable.

import importlib.util
import os
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
WRAPPER = (
    sys.argv.pop(1) if len(sys.argv) > 1 else os.path.join(HERE, "fastfetch-wrapper.py")
)

spec = importlib.util.spec_from_file_location("fastfetch_wrapper", WRAPPER)
ww = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ww)

ROWS = ["  Host: Test Machine", "  CPU: A very wide processor name (8) @ 4.00 GHz"]
WIDTH = max(len(r) for r in ROWS)

FAKE_FASTFETCH = textwrap.dedent(
    f"""\
    #!{sys.executable}
    import os, sys
    mode = os.environ.get("FAKE_MODE", "ok")
    args = sys.argv[1:]
    measuring = "true" in args and "--pipe" in args
    if "--version" in args:
        print("fastfetch 9.9.9 (fake)")
        sys.exit(0)
    if mode == "silent":
        sys.exit(3)
    if mode == "silent-real" and not measuring:
        sys.exit(4)
    if measuring:
        print("┌─── Hardware ───┐")
        for r in {ROWS!r}:
            print(r)
        print("└────────────────┘")
        sys.exit(0)
    print("\\x1b[32m┌─── \\x1b[32mHardware\\x1b[0m ───┐\\x1b[0m")
    print({ROWS[0]!r})
    sys.stdout.flush()
    if mode == "crash":
        os.abort()
    if mode == "hang":
        import time
        time.sleep(60)
    print({ROWS[1]!r})
    print("└────────────────┘")
    """
)


def plain(s):
    return ww.CSI.sub("", s).replace("\r", "")


class BannerTests(unittest.TestCase):
    def test_measure_width_ignores_banners_and_blank_lines(self):
        text = "┌──── Name ────────────────────────────────┐\n\n" + "\n".join(ROWS)
        self.assertEqual(ww.measure_width(text), WIDTH)

    def test_measure_width_of_nothing_is_zero(self):
        self.assertEqual(ww.measure_width(""), 0)

    def test_titled_banner_is_resized_and_centred(self):
        out = ww.resize_banners("├── Title ──┤", 20)
        self.assertEqual(out, "├───── Title ──────┤")
        self.assertEqual(len(out), 20)

    def test_untitled_banner_is_resized(self):
        self.assertEqual(ww.resize_banners("└──┘", 6), "└────┘")

    def test_colored_title_keeps_its_escapes_and_visible_width(self):
        banner = "┌── \x1b[33mOS / \x1b[34mDesktop\x1b[0m ──┐"
        out = ww.resize_banners(banner, 30)
        self.assertIn("\x1b[33mOS / \x1b[34mDesktop\x1b[0m", out)
        self.assertEqual(ww.visible_len(out), 30)

    def test_banner_after_cursor_escape_is_rewritten_in_place(self):
        line = "\x1b[38;5;1mLOGO\x1b[0m\x1b[40C┌── X ──┐"
        out = ww.resize_banners(line, 12)
        self.assertTrue(out.startswith("\x1b[38;5;1mLOGO\x1b[0m\x1b[40C"))
        self.assertTrue(out.endswith("┌─── X ────┐"))

    def test_title_wider_than_target_is_not_truncated(self):
        self.assertEqual(ww.resize_banners("├─ Long title ─┤", 6), "├ Long title ┤")

    def test_passthrough_flags(self):
        self.assertTrue(ww.is_passthrough(["--version"]))
        self.assertTrue(ww.is_passthrough(["--list-modules"]))
        self.assertTrue(ww.is_passthrough(["--gen-config-force"]))
        self.assertFalse(ww.is_passthrough(["--logo", "none"]))


def _pty_available():
    try:
        master, slave = os.openpty()
    except OSError:
        return False
    os.close(master)
    os.close(slave)
    return True


@unittest.skipUnless(_pty_available(), "no pseudo-terminals in this environment")
class EndToEndTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fake = os.path.join(cls.tmp.name, "fastfetch")
        with open(cls.fake, "w", encoding="utf-8") as f:
            f.write(FAKE_FASTFETCH)
        os.chmod(cls.fake, os.stat(cls.fake).st_mode | stat.S_IEXEC)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_wrapper(self, mode, *args, timeout=60):
        env = dict(os.environ, FASTFETCH_BIN=self.fake, FAKE_MODE=mode)
        env.pop("FASTFETCH_CONFIG", None)
        return subprocess.run(
            [sys.executable, "-I", WRAPPER, *args],
            check=False,
            capture_output=True,
            encoding="utf-8",
            env=env,
            timeout=timeout,
        )

    def banners(self, stdout):
        return [line for line in plain(stdout).splitlines() if line[:1] in "┌├└"]

    def test_banners_match_widest_row(self):
        r = self.run_wrapper("ok")
        self.assertEqual(r.returncode, 0, r.stderr)
        banners = self.banners(r.stdout)
        self.assertEqual(len(banners), 2)
        for b in banners:
            self.assertEqual(len(b), WIDTH)
        self.assertIn(ROWS[1], plain(r.stdout))

    def test_crash_mid_run_still_prints_partial_output(self):
        r = self.run_wrapper("crash")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn(ROWS[0], plain(r.stdout))
        self.assertEqual(len(self.banners(r.stdout)[0]), WIDTH)

    def test_silent_real_run_falls_back_to_measurement_output(self):
        r = self.run_wrapper("silent-real")
        self.assertEqual(r.returncode, 4)
        self.assertIn(ROWS[1], r.stdout)

    def test_no_output_at_all_reports_an_error(self):
        r = self.run_wrapper("silent")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("printed nothing", r.stderr)

    def test_hang_is_cut_off_and_partial_output_kept(self):
        os.environ["FAKE_MODE"] = "hang"
        try:
            rc, out, note = ww.run_with_controlling_pty([self.fake], timeout=3)
        finally:
            del os.environ["FAKE_MODE"]
        self.assertEqual(rc, 128 + 9)  # SIGKILL
        self.assertIn("timed out", note)
        self.assertIn(ROWS[0], plain(out))

    def test_informational_flags_pass_straight_through(self):
        r = self.run_wrapper("ok", "--version")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), "fastfetch 9.9.9 (fake)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
