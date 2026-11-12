#!/usr/bin/env python3
"""sert bootstrapper: verifies and runs the pinned sert release pyz from sert.toml + sert.lock (stdlib only)."""

from __future__ import annotations

import sys

if sys.version_info < (3, 11):
    print(f"sert: needs Python 3.11 or newer; this is {sys.version.split()[0]} ({sys.executable})", file=sys.stderr)
    sys.exit(2)

import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import tomllib
import urllib.error
import urllib.parse
import urllib.request

REPO = "kohltastrophe/sert"
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def die(msg: str) -> None:
    print(f"sert: {msg}", file=sys.stderr)
    raise SystemExit(2)


def cache_dir() -> Path:
    if env := os.environ.get("SERT_CACHE"):
        return Path(env)
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData/Local") / "sert"
    if sys.platform == "darwin":
        return Path.home() / "Library/Caches/sert"
    return Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "sert"


cache_root = cache_dir


def find_root(argv: list[str]) -> Path:
    for i, arg in enumerate(argv):
        if arg == "--root" and i + 1 < len(argv):
            return Path(argv[i + 1]).resolve()
        if arg.startswith("--root="):
            return Path(arg.split("=", 1)[1]).resolve()
    if env := os.environ.get("SERT_ROOT"):
        return Path(env).resolve()
    return Path(__file__).resolve().parents[1]


def load_toml(path: Path) -> dict:
    try:
        return tomllib.loads(path.read_text(encoding="utf-8-sig")) if path.is_file() else {}
    except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError) as err:
        die(f"{path}: {err}")


def parse_sums(text: str, label: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) != 2 or not HEX64.fullmatch(parts[0]):
            die(f"{label}: malformed SHA256SUMS line: {raw!r}")
        out[Path(parts[1].lstrip("*").strip()).name] = parts[0].lower()
    if not out:
        die(f"{label}: empty SHA256SUMS")
    return out


def lock_sha_for_pyz(root: Path, version: str) -> str | None:
    lock_path = root / "sert.lock"
    if not lock_path.is_file():
        return None
    data = load_toml(lock_path)
    lock_ver, assets = data.get("version"), data.get("assets")
    if not isinstance(lock_ver, str) or not isinstance(assets, dict):
        die("sert.lock: invalid lockfile structure")
    for entry in assets.values():
        if not isinstance(entry, dict) or not HEX64.fullmatch(str(entry.get("sha256", ""))):
            die("sert.lock: invalid asset sha256 entry")
    if lock_ver.strip() != version:
        return None
    pyz_entry = assets.get("sert.pyz") or assets.get(f"sert-{version}.pyz")
    return str(pyz_entry["sha256"]).lower() if isinstance(pyz_entry, dict) else None


class _DropAuth(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected and urllib.parse.urlparse(req.full_url).netloc != urllib.parse.urlparse(newurl).netloc:
            redirected.headers.pop("Authorization", None)
            redirected.unredirected_hdrs.pop("Authorization", None)
        return redirected


_RELEASE_CACHE: dict[tuple[str, str, str], dict[str, str]] = {}


def _read_exact(resp) -> bytes:
    data = resp.read()
    cl = resp.headers.get("Content-Length") if hasattr(resp, "headers") and resp.headers else None
    if cl and cl.isdigit() and len(data) < int(cl):
        raise http.client.IncompleteRead(data, int(cl) - len(data))
    return data


def fetch_bytes(url: str, repo: str, tag: str, asset_name: str) -> bytes:
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    host = urllib.parse.urlparse(url).netloc.lower()
    api_base = os.environ.get("SERT_GITHUB_API_URL", "").strip().rstrip("/")
    use_api = bool(token) and (host == "github.com" or bool(api_base))
    opener = urllib.request.build_opener(_DropAuth)
    try:
        if use_api:
            base = api_base or "https://api.github.com"
            key = (base, repo, tag)
            if key not in _RELEASE_CACHE:
                rel_req = urllib.request.Request(
                    f"{base}/repos/{repo}/releases/tags/{tag}",
                    headers={
                        "User-Agent": "sert-stub",
                        "Accept": "application/vnd.github+json",
                        "Authorization": f"Bearer {token}",
                    },
                )
                with opener.open(rel_req, timeout=60) as resp:
                    payload = json.loads(_read_exact(resp).decode("utf-8"))
                _RELEASE_CACHE[key] = {
                    str(a["name"]): str(a["url"])
                    for a in payload.get("assets", ())
                    if isinstance(a, dict) and a.get("name") and a.get("url")
                }
            asset_url = _RELEASE_CACHE[key].get(asset_name)
            if not asset_url:
                die(f"asset {asset_name!r} not found in release {repo}@{tag}")
            req = urllib.request.Request(
                asset_url,
                headers={
                    "User-Agent": "sert-stub",
                    "Accept": "application/octet-stream",
                    "Authorization": f"Bearer {token}",
                },
            )
        else:
            headers = {"User-Agent": "sert-stub"}
            if token and host in ("github.com", "api.github.com"):
                headers["Authorization"] = f"Bearer {token}"
            req = urllib.request.Request(url, headers=headers)
        with opener.open(req, timeout=120) as resp:
            return _read_exact(resp)
    except (OSError, ValueError, urllib.error.URLError, http.client.HTTPException) as err:
        die(f"download failed ({url}): {err}")


def ensure_verified_pyz(root: Path, repo: str, version: str, offline: bool) -> Path:
    cli_dir = cache_dir() / "cli"
    name = f"sert-{version}.pyz"
    pyz = cli_dir / name
    sums_file = cli_dir / f"sert-{version}.SHA256SUMS"
    locked_sha = lock_sha_for_pyz(root, version)
    base = os.environ.get("SERT_GITHUB_URL", "https://github.com").rstrip("/")
    tag = f"v{version}"
    sums_url = f"{base}/{repo}/releases/download/{tag}/SHA256SUMS"
    pyz_url = f"{base}/{repo}/releases/download/{tag}/{name}"

    if pyz.is_file():
        actual = hashlib.sha256(pyz.read_bytes()).hexdigest()
        expected = locked_sha
        if expected is None and sums_file.is_file():
            expected = parse_sums(sums_file.read_text(encoding="utf-8"), str(sums_file)).get(name)
        if expected is None:
            if offline:
                die(f"cannot verify cached {name} in --offline mode without sert.lock or cached SHA256SUMS")
            sums_bytes = fetch_bytes(sums_url, repo, tag, "SHA256SUMS")
            expected = parse_sums(sums_bytes.decode("utf-8", errors="replace"), sums_url).get(name)
            if expected:
                sums_file.write_bytes(sums_bytes)
        if not expected or actual != expected:
            die(f"SHA-256 verification failed for {name}: expected {expected}, got {actual}")
        return pyz

    if offline:
        die(f"{name} is not cached and --offline was passed")
    cli_dir.mkdir(parents=True, exist_ok=True)
    sums_bytes = fetch_bytes(sums_url, repo, tag, "SHA256SUMS")
    sums = parse_sums(sums_bytes.decode("utf-8", errors="replace"), sums_url)
    expected = sums.get(name)
    if not expected:
        die(f"SHA256SUMS for {tag} has no entry for {name}")
    if locked_sha and locked_sha != expected:
        die(f"SHA-256 mismatch between sert.lock ({locked_sha}) and SHA256SUMS ({expected}) for {name}")
    print(f"sert: downloading {name}", file=sys.stderr)
    data = fetch_bytes(pyz_url, repo, tag, name)
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        die(f"SHA-256 verification failed for {name}: expected {expected}, got {actual}")
    tmp = tempfile.NamedTemporaryFile(dir=cli_dir, prefix=f".{name}.", delete=False)
    try:
        tmp.write(data)
        tmp.close()
        os.chmod(tmp.name, 0o755)
        os.replace(tmp.name, pyz)
        sums_file.write_bytes(sums_bytes)
    except BaseException:
        if os.path.exists(tmp.name):
            os.unlink(tmp.name)
        raise
    return pyz


def _exec_child(cmd: list[str], env: dict[str, str]) -> int:
    proc = subprocess.Popen(cmd, env=env)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, lambda s, _f: proc.poll() is None and proc.terminate())
    try:
        rc = proc.wait()
    except KeyboardInterrupt:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        rc = proc.returncode if proc.returncode is not None else 130
    return 128 + (-rc) if rc < 0 else rc


def _run_checkout(checkout: Path, argv: list[str], env: dict[str, str]) -> int:
    py_dir = checkout / "python"
    if not (py_dir / "sert" / "__main__.py").is_file():
        die(f"sert checkout not found at {checkout}")
    env = {**env, "PYTHONPATH": str(py_dir) + (os.pathsep + p if (p := env.get("PYTHONPATH")) else "")}
    return _exec_child([sys.executable, "-P", "-m", "sert", *argv], env)


def main() -> int:
    argv = sys.argv[1:]
    root = find_root(argv)
    py_name = "python3" if os.name != "nt" else "python"
    env = {**os.environ, "SERT_ROOT": str(root), "SERT_PYTHON": os.environ.get("SERT_PYTHON") or py_name}
    if source := os.environ.get("SERT_SOURCE"):
        return _run_checkout(Path(os.path.expanduser(source)).resolve(), argv, env)
    shared = load_toml(root / "sert.toml")
    local = load_toml(root / "sert.local.toml")
    is_ci = os.environ.get("CI", "").strip().lower() in ("1", "true", "yes")
    if not is_ci:
        overrides = {**(shared.get("override") or {}), **(local.get("override") or {})}
        if isinstance(overrides, dict) and overrides.get("sert"):
            return _run_checkout((root / os.path.expanduser(str(overrides["sert"]))).resolve(), argv, env)
    cfg = {**(shared.get("sert") or {}), **(local.get("sert") or {})}
    version = str(cfg.get("version", "")).strip()
    if not version:
        if (root / "python" / "sert" / "__main__.py").is_file():
            return _run_checkout(root, argv, env)
        die(f"missing [sert].version in {root / 'sert.toml'}")
    repo = str(cfg.get("repo") or REPO).strip()
    offline = "--offline" in argv or os.environ.get("SERT_OFFLINE", "").strip().lower() in ("1", "true", "yes")
    pyz = ensure_verified_pyz(root, repo, version, offline=offline)
    return _exec_child([sys.executable, "-P", str(pyz), *argv], env)


if __name__ == "__main__":
    raise SystemExit(main())
