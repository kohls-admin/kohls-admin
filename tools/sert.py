#!/usr/bin/env python3
"""sert bootstrap: runs the sert that sert.toml pins. Commit this file unchanged; `sert lint` checks it.

Order: $SERT_SOURCE (a sert checkout, for CI against an unreleased ref), then [override].sert in sert.local.toml,
then sert-<version>.pyz from the GitHub release (the latest when [sert].version is unset), cached in $SERT_CACHE,
else %LOCALAPPDATA%\\sert, ~/Library/Caches/sert or ~/.cache/sert. $GITHUB_TOKEN goes to github.com only.
SERT_OFFLINE=1 runs a cached pyz only. Exit 2 on failure.
"""
import sys

if sys.version_info < (3, 11):
    print(f"sert: needs Python 3.11 or newer; this is {sys.version.split()[0]} ({sys.executable})", file=sys.stderr)
    sys.exit(2)

import http.client
import os
from pathlib import Path
import re
import signal
import ssl
import subprocess
import time
import tomllib
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
PY = "python" if sys.platform == "win32" else "python3"  # as the README says to run this stub


def fail(message):
    print(f"sert: {message}", file=sys.stderr)
    sys.exit(2)


def load(name):
    try:
        return tomllib.loads((ROOT / name).read_text(encoding="utf-8-sig")) if (ROOT / name).is_file() else {}
    except (OSError, ValueError) as err:  # TOMLDecodeError, UnicodeDecodeError
        fail(f"{name}: {err}")


def run(command, python_path=None):
    env = dict(os.environ, SERT_ROOT=str(ROOT), SERT_PYTHON=PY)
    if python_path:
        env["PYTHONPATH"] = os.pathsep.join(filter(None, [str(python_path), env.get("PYTHONPATH")]))
    process = subprocess.Popen(command + sys.argv[1:], env=env)
    signal.signal(signal.SIGTERM, lambda *_: process.terminate())
    while True:
        try:
            code = process.wait()
            return 128 - code if code < 0 else code  # killed by signal N: 128+N, as a shell reports it
        except KeyboardInterrupt:
            pass  # the child got the same Ctrl+C and stops what it started


def cache_dir():
    if os.environ.get("SERT_CACHE"):
        return Path(os.environ["SERT_CACHE"])
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local") / "sert"
    return Path.home() / ("Library/Caches" if sys.platform == "darwin" else ".cache") / "sert"


def download(url, method="GET"):
    request = urllib.request.Request(url, headers={"User-Agent": "sert"}, method=method)
    if os.environ.get("GITHUB_TOKEN") and url.startswith("https://github.com/"):
        request.add_unredirected_header("Authorization", f"Bearer {os.environ['GITHUB_TOKEN']}")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.geturl(), response.read()  # the URL after redirects
        except (urllib.error.URLError, OSError, http.client.HTTPException) as err:  # IncompleteRead: cut short
            code, reason = getattr(err, "code", None), getattr(err, "reason", err)
            if isinstance(reason, ssl.SSLCertVerificationError):
                fail(f"download failed: {url}: {reason}; Python may need its certificates installed"
                     " (macOS: run Install Certificates.command) or SSL_CERT_FILE set")
            if attempt == 3 or (code is not None and code != 429 and code < 500):
                fail(f"download failed: {url}: {f'HTTP {code}' if code else reason}")
            time.sleep(float(os.environ.get("SERT_RETRY_DELAY") or 1) * 2**attempt)


def main():
    toml, source, override = load("sert.toml"), os.environ.get("SERT_SOURCE"), load("sert.local.toml").get("override", {}).get("sert")
    if not (source or override or "sert" in toml) and (ROOT / "python" / "sert").is_dir():
        override = "."
    if source or override:
        target = Path(source or override).expanduser()
        checkout = target if source else (ROOT / target)
        if not (checkout / "python" / "sert").is_dir():
            fail(f"{'SERT_SOURCE' if source else '[override].sert in sert.local.toml'}: {checkout} is not a sert checkout (no python/sert)")
        return run([sys.executable, "-P", "-m", "sert"], checkout.resolve() / "python")  # -P: not the cwd's sert.py
    pin = toml.get("sert", {})
    version, repo = pin.get("version"), pin.get("repo", "kohltastrophe/sert")
    base = os.environ.get("SERT_GITHUB_URL", "https://github.com").rstrip("/") + "/" + repo
    offline = os.environ.get("SERT_OFFLINE", "").strip().lower() in ("1", "true", "yes")
    if not version and offline:
        fail("offline: sert.toml pins no [sert].version to look up in the cache")
    if not version:
        latest = download(f"{base}/releases/latest", "HEAD")[0]  # redirects to .../releases/tag/v<version>
        version = (re.search(r"/tag/v([^/?#]+)$", latest) or fail(f"cannot find the latest release ({latest})"))[1]
    name, release = f"sert-{version}.pyz", f"{base}/releases/download/v{version}"
    pyz = cache_dir() / repo / f"v{version}" / name
    if not pyz.is_file():
        if offline:
            fail(f"offline: {name} is not in the cache ({cache_dir()})")
        data = download(f"{release}/{name}")[1]
        pyz.parent.mkdir(parents=True, exist_ok=True)
        part = pyz.with_name(f".{name}.{os.getpid()}")
        try:
            part.write_bytes(data)
            os.replace(part, pyz)
        except BaseException:
            part.unlink(missing_ok=True)
            raise
    return run([sys.executable, str(pyz)])


if __name__ == "__main__":
    sys.exit(main())
