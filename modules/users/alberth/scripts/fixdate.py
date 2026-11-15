#!/usr/bin/env python3
"""Repair bogus Finder "Date Added" timestamps on APFS.

Finder's "Date Added" is the APFS ATTR_CMN_ADDEDTIME attribute, separate from
the creation and modification times. This script finds items whose added time
is implausibly old (before --cutoff, default 1990-01-01 local time) and resets
it to:

  1. the download date (com.apple.metadata:kMDItemDownloadedDate), else
  2. the creation (birth) time, else
  3. the modification time,

whichever is first to be plausible. File contents, modification times and
code signatures are not touched.

Dry run by default; pass --apply to write. Use sudo for items you don't own
(most of /Applications). SIP-protected items (e.g. Safari) cannot be changed.
Exits 1 if any item could not be read or changed.

Examples:
  fixdate.py ~/Downloads
  fixdate.py --apply ~/Downloads ~/Desktop ~/Documents
  sudo fixdate.py --apply --bad-date 2026-11-12 /Applications
"""

import argparse
import ctypes
import ctypes.util
import datetime as dt
import errno
import os
import plistlib
import sys
import time
from xml.parsers.expat import ExpatError

ATTR_BIT_MAP_COUNT = 5
ATTR_CMN_ADDEDTIME = 0x10000000
ATTR_CMN_RETURNED_ATTRS = 0x80000000
FSOPT_NOFOLLOW = 0x1
XATTR_NOFOLLOW = 0x1
DOWNLOADED_XATTR = b"com.apple.metadata:kMDItemDownloadedDate"
DEFAULT_CUTOFF = "1990-01-01"
# dt.UTC needs Python 3.11; sudo runs /usr/bin/python3, which is 3.9.
UTC = dt.timezone.utc  # noqa: UP017
FUTURE_SLACK = 86400  # replacements up to a day ahead of now are accepted

# Directories treated as single items: their insides are not scanned.
# Lowercase; matched case-insensitively.
PACKAGE_EXTS = frozenset(
    {
        ".app",
        ".appex",
        ".bundle",
        ".framework",
        ".plugin",
        ".kext",
        ".pkg",
        ".mpkg",
        ".xpc",
        ".photoslibrary",
        ".musiclibrary",
        ".tvlibrary",
        ".photolibrary",
        ".aplibrary",
        ".fcpbundle",
        ".logicx",
        ".band",
        ".pages",
        ".numbers",
        ".key",
        ".rtfd",
        ".xcodeproj",
        ".xcworkspace",
        ".playground",
        ".qlgenerator",
        ".mdimporter",
        ".prefpane",
        ".saver",
        ".component",
        ".vst",
        ".vst3",
        ".dsym",
        ".lproj",
        ".sparsebundle",
        ".imovielibrary",
        ".theater",
        ".nib",
        ".xcassets",
    }
)


class AttrList(ctypes.Structure):
    _fields_ = [
        ("bitmapcount", ctypes.c_uint16),
        ("reserved", ctypes.c_uint16),
        ("commonattr", ctypes.c_uint32),
        ("volattr", ctypes.c_uint32),
        ("dirattr", ctypes.c_uint32),
        ("fileattr", ctypes.c_uint32),
        ("forkattr", ctypes.c_uint32),
    ]


class Timespec(ctypes.Structure):
    _fields_ = [("tv_sec", ctypes.c_long), ("tv_nsec", ctypes.c_long)]


class AddedTimeBuf(ctypes.Structure):
    # getattrlist packs attributes at 4-byte alignment; `added` lands at
    # offset 24 (4 + 5 * 4), which natural alignment also gives here.
    _fields_ = [
        ("length", ctypes.c_uint32),
        ("returned", ctypes.c_uint32 * 5),
        ("added", Timespec),
    ]


_libc = None


def libc():
    """Load libc and declare the macOS calls on first use."""
    global _libc
    if _libc is None:
        lib = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
        attrlist_args = [
            ctypes.c_char_p,
            ctypes.POINTER(AttrList),
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_uint,
        ]
        lib.getattrlist.argtypes = attrlist_args
        lib.setattrlist.argtypes = attrlist_args
        lib.getxattr.argtypes = [
            ctypes.c_char_p,
            ctypes.c_char_p,
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_uint32,
            ctypes.c_int,
        ]
        lib.getxattr.restype = ctypes.c_ssize_t
        _libc = lib
    return _libc


def _oserror(path):
    e = ctypes.get_errno()
    return OSError(e, os.strerror(e), path)


def get_added_time(path):
    """Return the Date Added as a POSIX timestamp, or None if the item has none."""
    al = AttrList(
        ATTR_BIT_MAP_COUNT, 0, ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_ADDEDTIME, 0, 0, 0, 0
    )
    buf = AddedTimeBuf()
    rc = libc().getattrlist(
        os.fsencode(path),
        ctypes.byref(al),
        ctypes.byref(buf),
        ctypes.sizeof(buf),
        FSOPT_NOFOLLOW,
    )
    if rc != 0:
        raise _oserror(path)
    if not buf.returned[0] & ATTR_CMN_ADDEDTIME:
        return None
    return buf.added.tv_sec + buf.added.tv_nsec / 1e9


def set_added_time(path, ts):
    al = AttrList(ATTR_BIT_MAP_COUNT, 0, ATTR_CMN_ADDEDTIME, 0, 0, 0, 0)
    sec = int(ts)
    t = Timespec(sec, round((ts - sec) * 1e9))
    rc = libc().setattrlist(
        os.fsencode(path),
        ctypes.byref(al),
        ctypes.byref(t),
        ctypes.sizeof(t),
        FSOPT_NOFOLLOW,
    )
    if rc != 0:
        raise _oserror(path)


def read_xattr(path, name):
    """Return the raw value of extended attribute `name`, or None."""
    p = os.fsencode(path)
    size = libc().getxattr(p, name, None, 0, 0, XATTR_NOFOLLOW)
    if size <= 0:
        return None
    buf = ctypes.create_string_buffer(size)
    n = libc().getxattr(p, name, buf, size, 0, XATTR_NOFOLLOW)
    if n <= 0:
        return None
    return buf.raw[:n]


def parse_downloaded_date(raw):
    """Return the earliest date in a kMDItemDownloadedDate plist, or None."""
    try:
        value = plistlib.loads(raw)
    except (ValueError, ExpatError):  # InvalidFileException is a ValueError
        return None
    dates = value if isinstance(value, list) else [value]
    # plistlib returns naive datetimes in UTC.
    stamps = [
        d.replace(tzinfo=UTC).timestamp() for d in dates if isinstance(d, dt.datetime)
    ]
    return min(stamps) if stamps else None


def get_downloaded_time(path):
    raw = read_xattr(path, DOWNLOADED_XATTR)
    return None if raw is None else parse_downloaded_date(raw)


def in_windows(ts, windows):
    return any(start <= ts < end for start, end in windows)


def choose_replacement(path, cutoff, now, windows=()):
    """Return (timestamp, source) for the best plausible date, or (None, None)."""
    st = os.lstat(path)
    for source, ts in (
        ("downloaded", get_downloaded_time(path)),
        ("created", getattr(st, "st_birthtime", None)),
        ("modified", st.st_mtime),
    ):
        if (
            ts is not None
            and cutoff <= ts <= now + FUTURE_SLACK
            and not in_windows(ts, windows)
        ):
            return ts, source
    return None, None


def is_package(name):
    return os.path.splitext(name)[1].lower() in PACKAGE_EXTS


def iter_items(roots, into_packages, one_filesystem, on_error):
    """Yield every path under `roots`; report unreadable ones to `on_error`."""
    for root in roots:
        root = os.path.abspath(os.path.expanduser(root))
        try:
            st = os.lstat(root)
        except OSError as e:
            on_error(e)
            continue
        yield root
        if not os.path.isdir(root) or os.path.islink(root):
            continue
        if not into_packages and is_package(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root, onerror=on_error):
            keep = []
            for d in dirnames:
                full = os.path.join(dirpath, d)
                yield full
                if not into_packages and is_package(d):
                    continue
                if one_filesystem:
                    try:
                        if os.lstat(full).st_dev != st.st_dev:
                            continue
                    except OSError as e:
                        on_error(e)
                        continue
                keep.append(d)
            dirnames[:] = keep
            for f in filenames:
                yield os.path.join(dirpath, f)


def fmt(ts):
    return dt.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def parse_day(day):
    """Parse YYYY-MM-DD as local midnight; argparse type."""
    try:
        return dt.datetime.strptime(day, "%Y-%m-%d")
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"invalid date {day!r}, expected YYYY-MM-DD"
        ) from None


def day_window(day):
    """Local-time [start, end) timestamps for a local-midnight datetime."""
    return day.timestamp(), (day + dt.timedelta(days=1)).timestamp()


def run(
    roots,
    cutoff,
    windows=(),
    apply=False,
    into_packages=False,
    one_filesystem=True,
    verbose=True,
    out=sys.stdout,
    err=sys.stderr,
):
    """Scan `roots`; `cutoff` and `windows` are POSIX timestamps. Returns stats."""
    now = time.time()
    stats = dict.fromkeys(
        ("scanned", "bad", "fixed", "no_source", "denied", "errors"), 0
    )
    denied = []

    def report_error(e, label="ERROR "):
        stats["errors"] += 1
        print(f"{label} {e.filename}: {e.strerror}", file=err)

    for path in iter_items(roots, into_packages, one_filesystem, report_error):
        stats["scanned"] += 1
        try:
            added = get_added_time(path)
        except OSError as e:
            report_error(e)
            continue
        if added is None or not (added < cutoff or in_windows(added, windows)):
            continue
        stats["bad"] += 1
        try:
            new, source = choose_replacement(path, cutoff, now, windows)
        except OSError as e:
            report_error(e)
            continue
        if new is None:
            stats["no_source"] += 1
            if verbose:
                print(f"SKIP   {path}: no plausible date to use", file=out)
            continue
        verb, reason = ("FIX   " if apply else "WOULD "), ""
        if apply:
            try:
                set_added_time(path, new)
                stats["fixed"] += 1
            except OSError as e:
                reason = f" [{e.strerror}]"
                if e.errno in (errno.EPERM, errno.EACCES):
                    stats["denied"] += 1
                    denied.append(path)
                    verb = "DENIED"
                else:
                    stats["errors"] += 1
                    verb = "ERROR "
        if verbose or reason:
            print(
                f"{verb} {path}: {fmt(added)} -> {fmt(new)} ({source}){reason}",
                file=err if reason else out,
            )

    print(
        f"\nScanned {stats['scanned']} items; {stats['bad']} with bogus Date Added.",
        file=out,
    )
    if apply:
        print(
            f"Fixed {stats['fixed']}, permission denied {stats['denied']}, "
            f"no usable date {stats['no_source']}, other errors "
            f"{stats['errors']}.",
            file=out,
        )
        if denied and os.geteuid() != 0:
            print(
                "Re-run with sudo for the denied items. Items still denied "
                "under sudo are SIP-protected.",
                file=out,
            )
    else:
        print(
            f"No usable date {stats['no_source']}, errors {stats['errors']}.",
            file=out,
        )
        print("Dry run: nothing changed. Re-run with --apply to write.", file=out)
    return stats


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("paths", nargs="+", help="files or folders to scan")
    ap.add_argument(
        "--apply", action="store_true", help="write changes (default is a dry run)"
    )
    ap.add_argument(
        "--cutoff",
        type=parse_day,
        default=DEFAULT_CUTOFF,
        metavar="YYYY-MM-DD",
        help="Date Added before this local date is bogus (default %(default)s)",
    )
    ap.add_argument(
        "--bad-date",
        type=parse_day,
        action="append",
        default=[],
        metavar="YYYY-MM-DD",
        help="also treat a Date Added on this local day as bogus "
        "(repeatable); replacements on that day are rejected",
    )
    ap.add_argument(
        "--into-packages",
        action="store_true",
        help="also scan inside .app bundles and other packages",
    )
    ap.add_argument(
        "--cross-filesystems",
        action="store_true",
        help="descend into other mounted volumes",
    )
    ap.add_argument(
        "-q", "--quiet", action="store_true", help="only print errors and the summary"
    )
    args = ap.parse_args(argv)

    if sys.platform != "darwin":
        ap.error("this only works on macOS (APFS Date Added)")

    stats = run(
        args.paths,
        cutoff=args.cutoff.timestamp(),
        windows=[day_window(d) for d in args.bad_date],
        apply=args.apply,
        into_packages=args.into_packages,
        one_filesystem=not args.cross_filesystems,
        verbose=not args.quiet,
    )
    return 1 if stats["errors"] or stats["denied"] else 0


if __name__ == "__main__":
    sys.exit(main())
