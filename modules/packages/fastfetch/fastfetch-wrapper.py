#!/usr/bin/env python3
# Wrapper around fastfetch that resizes section banners to fit the widest
# data row.  The banners in the fastfetch config are static strings like
# "┌──...── NAME ──...──┐"; fastfetch has no built-in way to size them to
# match runtime content.
#
# Strategy (two runs):
#   1. Measurement run: `--logo none --pipe true` — gives plain-text, sequential
#      output with no ANSI codes and no cursor-positioning trickery.  Easy to
#      parse via captured pipe; max visible width across data rows is the
#      target banner size.
#   2. Real run: pass-through invocation that keeps the logo + colors.  Runs
#      under `pty.fork()` so the child gets a proper controlling-TTY PTY (not
#      just a slave fd as stdout).  Required on macOS where fastfetch's
#      terminal-mode output (`--pipe false`) opens `/dev/tty` directly; a
#      controlling-TTY PTY makes the child's `/dev/tty` resolve to our slave,
#      so we capture all of fastfetch's output regardless of which fd it
#      writes to.
#
# Failure handling — the wrapper always prints something:
#   - Measurement run fails: the real run's output is printed un-rewritten.
#   - Real run crashes, times out or is interrupted part-way: whatever it
#     printed so far is still rewritten and printed.  PTY output is
#     line-buffered, so a mid-run abort() still leaves the earlier lines.
#   - Real run prints nothing: the measurement run's plain-text output is
#     printed instead; if that is empty too, an error naming fastfetch's exit
#     status (and anything it wrote to stderr) goes to stderr.
#
# Informational flags (--help, --version, --list-*, --print-*, --gen-config*)
# skip all of this and exec the real binary directly.
#
# Env vars:
#   FASTFETCH_BIN     — path to the real fastfetch binary (default: "fastfetch").
#                       The Nix package sets it to the store path; leaving it at
#                       "fastfetch" while this wrapper shadows `fastfetch` on
#                       PATH would make the wrapper call itself.
#   FASTFETCH_CONFIG  — explicit config path; if unset, fastfetch auto-loads
#                       its default (~/.config/fastfetch/config.jsonc). The
#                       wrapper deliberately does NOT pass --config when this
#                       env is unset because fastfetch refuses to merge an
#                       auto-loaded default + an explicit --config ("only one
#                       config file can be loaded").
#   FASTFETCH_WRAPPER_DEBUG — set to anything to log the wrapper's steps to
#                       stderr.
#
# All other CLI args are passed through to fastfetch.

import fcntl
import os
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import termios
import time

ANSI = re.compile(r"\x1b\[[0-9;]*m")
# Any CSI escape (colors, cursor movement) — used only to decide whether the
# real run printed anything visible.
CSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")

# Banner regex — finds an occurrence anywhere in the line.  Fastfetch overlays
# the info column on the logo via cursor-positioning escapes (`\x1b[71C` etc.);
# those are outside this regex's window, so `re.sub` rewrites only the banner.
BANNER_RE = re.compile(
    r"((?:\x1b\[[0-9;]*m)*)"  # 1: ANSI prefix
    r"([┌├└])"  # 2: left corner
    r"(─+)"  # 3: left dashes
    r"(?: "
    r"((?:\x1b\[[0-9;]*m|[^─\x1b])+?)"  # 4: name w/ inline ANSI (multi-color titles)
    r" "
    r"(─+))?"  # 5: right dashes
    r"([┐┤┘])"  # 6: right corner
)

PLAIN_BANNER_RE = re.compile(r"^\s*[┌├└]─.*[┐┤┘]\s*$")

PASSTHROUGH_FLAGS = ("-h", "-v", "--help", "--version")
PASSTHROUGH_PREFIXES = ("--help", "--list-", "--print-", "--gen-config")

PTY_TIMEOUT = 30  # seconds


def visible_len(s):
    return len(ANSI.sub("", s))


def has_visible_output(s):
    return bool(CSI.sub("", s).strip())


def is_passthrough(args):
    return any(
        a in PASSTHROUGH_FLAGS or a.startswith(PASSTHROUGH_PREFIXES) for a in args
    )


def measure_width(plain_text):
    """Widest non-banner row of the plain-text measurement output (0 if none)."""
    widths = [
        len(line)
        for line in plain_text.splitlines()
        if line.strip() and not PLAIN_BANNER_RE.match(line)
    ]
    return max(widths, default=0)


def resize_banners(text, target_width):
    """Redraw every banner in `text` so it is `target_width` columns wide."""
    inner = target_width - 2  # subtract two corners
    if inner < 0:
        return text

    def replace_banner(m):
        ansi_l, cl, _, name, _, cr = m.groups()
        if name is None:
            return ansi_l + cl + "─" * inner + cr
        total_dashes = max(0, inner - 2 - visible_len(name))  # 2 spaces around name
        left = total_dashes // 2
        right = total_dashes - left
        return ansi_l + cl + "─" * left + " " + name + " " + "─" * right + cr

    return BANNER_RE.sub(replace_banner, text)


def _exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


def _term_size():
    """(rows, cols) for the pty winsize.  Mirror the user's real terminal when
    available so fastfetch picks a sensible line-wrap point; fall back to a
    wide default when stdout is piped/redirected."""
    try:
        cols, rows = shutil.get_terminal_size((200, 50))
    except OSError:
        cols, rows = 200, 50
    return rows, cols


def run_piped(cmd):
    """Captured-pipe run.  Used only for the measurement pass — that pass
    forces `--pipe true` which always writes plain text to stdout, so a pipe
    works fine on every platform."""
    try:
        r = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            stdin=subprocess.DEVNULL,
            encoding="utf-8",
            errors="replace",
            timeout=PTY_TIMEOUT,
        )
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired as e:
        partial = e.stdout or b""
        if isinstance(partial, bytes):
            partial = partial.decode("utf-8", errors="replace")
        return -1, partial, "fastfetch wrapper: measurement run timed out\n"
    except Exception as e:  # noqa: BLE001
        return -1, "", f"fastfetch wrapper: measurement run failed: {e}\n"


def _reap(pid, kill):
    if kill:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        _, status = os.waitpid(pid, 0)
        return _exit_code(status)
    except ChildProcessError:
        return 0


def run_with_controlling_pty(cmd, timeout=PTY_TIMEOUT):
    """Run `cmd` under a controlling-TTY PTY via `pty.fork()`.  Child stdin/
    stdout/stderr are all wired to the slave; opening `/dev/tty` inside the
    child also resolves to the slave.  Parent reads everything via the
    returned master fd.

    Returns `(returncode, output_text, note)`.  The child's stderr is merged
    into its output by the pty.  `note` is the wrapper's own diagnostic (or
    ""); the output captured so far is returned even when the run times out
    or is interrupted."""
    rows, cols = _term_size()
    try:
        pid, master_fd = pty.fork()
    except OSError as e:
        return -1, "", f"fastfetch wrapper: pty.fork failed: {e}\n"

    if pid == 0:
        # Child — slave is fd 0/1/2 + controlling tty.
        try:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        except OSError:
            pass
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            os.write(2, f"fastfetch wrapper: cannot run {cmd[0]}: {e}\n".encode())
        os._exit(127)

    chunks = []
    note = ""
    rc = None
    deadline = time.monotonic() + timeout
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                rc = _reap(pid, kill=True)
                note = f"fastfetch wrapper: fastfetch timed out after {timeout}s\n"
                break
            ready, _, _ = select.select([master_fd], [], [], min(remaining, 0.5))
            if ready:
                try:
                    data = os.read(master_fd, 65536)
                except OSError:
                    # EIO is the normal end-of-file signal on a pty master when
                    # the slave is closed (which happens when the child exits).
                    data = b""
                if data:
                    chunks.append(data)
                    continue
                rc = _reap(pid, kill=False)
                break
            # Nothing to read yet — check whether the child has exited.
            try:
                done_pid, status = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                done_pid, status = pid, 0
            if done_pid:
                # Drain any output still buffered in the master.
                while select.select([master_fd], [], [], 0.05)[0]:
                    try:
                        data = os.read(master_fd, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    chunks.append(data)
                rc = _exit_code(status)
                break
    except KeyboardInterrupt:
        rc = _reap(pid, kill=True)
        note = "fastfetch wrapper: interrupted\n"
    finally:
        try:
            os.close(master_fd)
        except OSError:
            pass

    return rc, b"".join(chunks).decode("utf-8", errors="replace"), note


def _debug(msg):
    if os.environ.get("FASTFETCH_WRAPPER_DEBUG"):
        sys.stderr.write(f"[wrapper] {msg}\n")


def main(argv=None):
    # Force UTF-8 stdout regardless of locale — macOS without LANG=…UTF-8 falls
    # back to ASCII and would otherwise mojibake every Nerd Font glyph.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    args = sys.argv[1:] if argv is None else argv
    bin_path = os.environ.get("FASTFETCH_BIN", "fastfetch")
    config = os.environ.get("FASTFETCH_CONFIG")
    base_args = (["--config", config] if config else []) + args
    _debug(f"bin={bin_path} config={config!r} extra_args={args!r}")
    _debug(f"platform={sys.platform} python={sys.version.split()[0]}")

    if is_passthrough(args):
        _debug("informational flag; exec'ing fastfetch directly")
        sys.stdout.flush()
        try:
            os.execvp(bin_path, [bin_path] + base_args)
        except OSError as e:
            sys.stderr.write(f"fastfetch wrapper: cannot run {bin_path}: {e}\n")
            return 127

    # 1. Measurement run — plain text, no logo.  Failures here are non-fatal.
    measure_cmd = [bin_path] + base_args + ["--logo", "none", "--pipe", "true"]
    _debug(f"measure cmd: {measure_cmd}")
    m_rc, m_out, m_err = run_piped(measure_cmd)
    _debug(f"measure rc={m_rc} stdout_len={len(m_out)} stderr_len={len(m_err)}")
    if m_err:
        _debug(f"measure stderr: {m_err.strip()!r}")
    # Only trust the width of a complete run; a partial one may miss the
    # widest row.
    target_width = measure_width(m_out) if m_rc == 0 else 0
    _debug(f"target_width={target_width}")

    # 2. Real run — colors + logo under a controlling-TTY PTY.
    real_cmd = [bin_path] + base_args + ["--pipe", "false"]
    _debug(f"real cmd: {real_cmd}")
    rc, out, note = run_with_controlling_pty(real_cmd)
    _debug(f"real rc={rc} stdout_len={len(out)}")

    if not has_visible_output(out):
        # Nothing usable from the real run; fall back to the measurement run.
        _debug("real run printed nothing; falling back to measurement output")
        out = m_out
        if rc == 0 and m_rc != 0:
            rc = m_rc

    if out:
        if target_width > 0:
            out = resize_banners(out, target_width)
        sys.stdout.write(out)
        if not out.endswith("\n"):
            sys.stdout.write("\n")
        sys.stdout.flush()
    if note:
        sys.stderr.write(note)
    if not out:
        if m_err:
            sys.stderr.write(m_err)
        sys.stderr.write(
            f"fastfetch wrapper: fastfetch printed nothing (exit status {rc})\n"
        )
        return rc if rc and rc > 0 else 1
    return rc if rc and rc > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
