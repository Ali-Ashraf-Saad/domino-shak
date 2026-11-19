#!/usr/bin/env python3
"""Domino Shak — explicit FTPS web deployment helper.

Security properties (do not weaken):
  * Explicit FTPS only: AUTH TLS on port 21, then PROT P for the data channel.
    There is no code path that sends USER/PASS over a plaintext connection.
  * The TLS certificate AND hostname are verified against the system CA store.
    If verification fails the script aborts; it never disables verification.
  * Credentials are read with getpass (hidden terminal) and held only in local
    variables for the lifetime of this process. They are never written to a
    file, never placed in argv or the environment, and never printed.
  * Must be run from an interactive TTY; a non-TTY stdin is rejected so the
    password prompt cannot be piped or captured.
  * Write operations are explicit and confirmed; inspection/backup are read-only
    with respect to the remote site.

Nothing in this file contains credentials, secrets, or a fallback to FTP.
"""

from __future__ import annotations

import getpass
import hashlib
import io
import os
import posixpath
import ssl
import sys
from datetime import datetime
from ftplib import FTP_TLS, error_perm, error_temp
from pathlib import Path

HOST = "ftpupload.net"
PORT = 21
# Supplied by the maintainer (non-secret hosting path).
DEFAULT_LIVE_ROOT = "/liardominoes.gt.tc/htdocs"
PROJECT = Path(__file__).resolve().parent.parent
BUILD_DIR = PROJECT / "domino_shak_web"
BACKUP_ROOT = PROJECT / "deployment_backups"

# Paths we are allowed to change on the host. Everything else is left alone.
MANAGED_FILES = {
    ".well-known/assetlinks.json.template",
    "README.md",
    "SHA256SUMS.txt",
    "config.js",
    "deployment/upload_instructions.md",
    "index.html",
    "PRIVACY_POLICY.html",
}
MANAGED_DIRS = {"fonts", "vendor", "deployment", ".well-known"}


def fail(message: str) -> "NoReturn":  # type: ignore[valid-type]
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


# --------------------------------------------------------------------------- #
# Connection — explicit FTPS with verified certificate, no plaintext fallback.
# --------------------------------------------------------------------------- #
def connect(user: str, password: str) -> FTP_TLS:
    context = ssl.create_default_context()
    context.check_hostname = True
    context.verify_mode = ssl.CERT_REQUIRED
    context.minimum_version = ssl.TLSVersion.TLSv1_2

    ftp = FTP_TLS(context=context, timeout=45)
    ftp.connect(HOST, PORT)  # Port 21: explicit TLS, NOT implicit ftps:// 990.
    ftp.auth()  # Send AUTH TLS; upgrade before any credential is transmitted.
    if not isinstance(ftp.sock, ssl.SSLSocket):
        ftp.close()
        fail("AUTH TLS did not upgrade the socket. Refusing to continue.")
    cert = ftp.sock.getpeercert()
    if not cert:
        ftp.close()
        fail("Server did not present a certificate.")
    ftp.login(user, password)  # FTP_TLS.login() skips re-auth; socket is TLS.
    ftp.prot_p()  # PROT P: encrypt the data channel too (listings + transfers).
    print(f"  TLS active: {ftp.sock.version()}, certificate verified for {HOST}")
    return ftp


# --------------------------------------------------------------------------- #
# Remote filesystem helpers. All paths are absolute from the FTP root.
# --------------------------------------------------------------------------- #
def entries(ftp: FTP_TLS) -> list[tuple[str, str]]:
    """List (name, type) of the current directory; type is 'dir' or 'file'."""
    try:
        result = []
        for name, facts in ftp.mlsd():
            if name in (".", ".."):
                continue
            kind = (facts.get("type") or "file").lower()
            result.append((name, "dir" if kind == "dir" else "file"))
        return result
    except (error_perm, error_temp):
        # Some servers disable MLSD. Fall back to LIST; no credentials involved.
        lines: list[str] = []
        ftp.retrlines("LIST", lines.append)
        result = []
        for line in lines:
            parts = line.split(None, 5)
            if len(parts) < 6:
                continue
            name = parts[5]
            if name in (".", ".."):
                continue
            result.append((name, "dir" if parts[0].startswith("d") else "file"))
        return result


def walk(ftp: FTP_TLS, root: str) -> dict[str, str]:
    """Map relative path -> type for every entry under an absolute root."""
    out: dict[str, str] = {}
    stack = [root.rstrip("/") or "/"]
    while stack:
        current = stack.pop()
        ftp.cwd(current)
        rel_dir = posixpath.relpath(current, root).replace("\\", "/")
        for name, kind in entries(ftp):
            rel = name if rel_dir == "." else posixpath.join(rel_dir, name)
            out[rel] = kind
            if kind == "dir":
                stack.append(posixpath.join(current, name))
        ftp.cwd("/")
    return out


def ensure_dir(ftp: FTP_TLS, path: str) -> None:
    parts = [part for part in path.split("/") if part]
    current = ""
    for part in parts:
        current += "/" + part
        try:
            ftp.cwd(current)
        except error_perm:
            ftp.mkd(current)
            ftp.cwd(current)
    ftp.cwd("/")


def exists(ftp: FTP_TLS, path: str) -> bool:
    try:
        ftp.cwd(path)
        ftp.cwd("/")
        return True
    except error_perm:
        return False


def show_tree(ftp: FTP_TLS, root: str = "/", limit: int = 200) -> None:
    ftp.cwd(root)
    found = entries(ftp)
    ftp.cwd("/")
    print(f"\nRemote root listing of {root}:")
    for name, kind in sorted(found)[:limit]:
        print(f"  {'dir ' if kind == 'dir' else 'file'}  {name}")
    if len(found) > limit:
        print(f"  ... {len(found) - limit} more entries")


# --------------------------------------------------------------------------- #
# Operations.
# --------------------------------------------------------------------------- #
def do_backup(ftp: FTP_TLS, root: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = BACKUP_ROOT / stamp
    target.mkdir(parents=True, exist_ok=False)
    manifest = target / "BACKUP_SHA256SUMS.txt"
    hashes: list[str] = []
    count = 0

    for rel, kind in sorted(walk(ftp, root).items()):
        destination = target / rel
        if kind == "dir":
            destination.mkdir(parents=True, exist_ok=True)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("wb") as handle:
            ftp.retrbinary(f"RETR {posixpath.join(root, rel)}", handle.write)
        hashes.append(f"{sha256_file(destination)}  {rel}")
        count += 1

    manifest.write_text("\n".join(hashes) + ("\n" if hashes else ""), encoding="utf-8")
    print(f"\nBackup complete: {count} files -> {target}")
    print(f"Manifest: {manifest}")
    return target


def do_upload(ftp: FTP_TLS, destination: str) -> int:
    if not BUILD_DIR.is_dir():
        fail(f"Build directory missing: {BUILD_DIR}")
    ensure_dir(ftp, destination)
    uploaded = 0
    for path in sorted(p for p in BUILD_DIR.rglob("*") if p.is_file()):
        rel = path.relative_to(BUILD_DIR).as_posix()
        if rel.startswith(".well-known/"):
            # No real assetlinks.json exists without the Play fingerprint; the
            # template stays local. Do not publish any /.well-known/ content.
            continue
        remote_dir = posixpath.join(destination, posixpath.dirname(rel))
        ensure_dir(ftp, remote_dir)
        with path.open("rb") as handle:
            ftp.storbinary(f"STOR {posixpath.join(destination, rel)}", handle)
        uploaded += 1
        print(f"  uploaded {rel} ({path.stat().st_size} bytes)")
    print(f"\nUploaded {uploaded} files to {destination}")
    return uploaded


def remote_bytes(ftp: FTP_TLS, path: str) -> bytes:
    buffer = io.BytesIO()
    ftp.retrbinary(f"RETR {path}", buffer.write)
    return buffer.getvalue()


def do_promote(ftp: FTP_TLS, staging: str, live: str) -> int:
    """Copy managed files from staging into live. Never deletes remote files."""
    staged = walk(ftp, staging)
    changed = 0
    for rel, kind in sorted(staged.items()):
        top = rel.split("/", 1)[0]
        if kind == "dir":
            if top in MANAGED_DIRS:
                ensure_dir(ftp, posixpath.join(live, rel))
            continue
        allowed = rel in MANAGED_FILES or top in MANAGED_DIRS
        if not allowed:
            print(f"  skipped unmanaged file: {rel}")
            continue
        destination = posixpath.join(live, rel)
        ensure_dir(ftp, posixpath.dirname(destination))
        payload = remote_bytes(ftp, posixpath.join(staging, rel))
        with io.BytesIO(payload) as handle:
            ftp.storbinary(f"STOR {destination}", handle)
        changed += 1
        print(f"  promoted {rel} ({len(payload)} bytes)")
    print(f"\nPromoted {changed} files into {live}. No remote files were deleted.")
    return changed


def do_rollback(ftp: FTP_TLS, backup: Path, live: str) -> int:
    """Restore backed-up files over the live root, without deleting extras."""
    if not backup.is_dir():
        fail(f"Backup folder not found: {backup}")
    restored = 0
    for path in sorted(p for p in backup.rglob("*") if p.is_file()):
        rel = path.relative_to(backup).as_posix()
        if rel == "BACKUP_SHA256SUMS.txt":
            continue
        destination = posixpath.join(live, rel)
        ensure_dir(ftp, posixpath.dirname(destination))
        with path.open("rb") as handle:
            ftp.storbinary(f"STOR {destination}", handle)
        restored += 1
        print(f"  restored {rel}")
    print(f"\nRestored {restored} files into {live} from {backup}.")
    print("Note: files added after the backup were not deleted; review manually.")
    return restored


def detect_live_root(ftp: FTP_TLS) -> str | None:
    for candidate in (
        DEFAULT_LIVE_ROOT,
        "/htdocs",
        "/public_html",
        "/www",
        "/domains/liardominoes.gt.tc",
    ):
        if exists(ftp, candidate):
            return candidate
    return None


# --------------------------------------------------------------------------- #
# Interactive menu.
# --------------------------------------------------------------------------- #
def main() -> None:
    if not sys.stdin.isatty():
        fail("Run this in an interactive terminal so the password prompt is hidden.")
    if not (HOST, PORT) == ("ftpupload.net", 21):
        fail("Unexpected target configuration.")

    print("Domino Shak — explicit FTPS deployment")
    print(f"Target: {HOST}:{PORT}  (AUTH TLS + PROT P, certificate verified)")
    print(f"Local build: {BUILD_DIR}")
    print("Credentials are hidden and kept only in memory for this session.\n")

    user = input("FTP username: ").strip()
    password = getpass.getpass("FTP password: ")
    if not user or not password:
        fail("Username and password are both required.")

    ftp = connect(user, password)
    del user, password

    root: str | None = None
    staging: str | None = None
    last_backup: Path | None = None

    try:
        print(f"Logged in. Initial directory: {ftp.pwd()}")
        while True:
            print("\n=== MENU ===")
            print(" 1) Inspect remote structure (read-only)")
            print(" 2) Set / confirm live web root")
            print(" 3) Back up live site (read-only on remote)")
            print(" 4) Upload build to staging")
            print(" 5) Promote staging -> live (no deletions)")
            print(" 6) Rollback from a local backup")
            print(" 7) Quit")
            choice = input(f"Select [current live={root or 'unset'}, staging={staging or 'unset'}]: ").strip()

            if choice == "1":
                show_tree(ftp, root or "/")
            elif choice == "2":
                detected = detect_live_root(ftp)
                print(f"Auto-detected web root: {detected or 'none'}")
                answer = input(
                    f"Web root absolute path (Enter to accept: {detected or root or DEFAULT_LIVE_ROOT}): "
                ).strip()
                root = answer or detected or root or DEFAULT_LIVE_ROOT
                if root:
                    if not exists(ftp, root):
                        fail(f"Remote path does not exist: {root}")
                    staging = posixpath.join(root, "_staging")
                    print(f"Live root: {root}")
                    print(f"Staging path: {staging}  ->  https://liardominoes.gt.tc/_staging/")
            elif choice == "3":
                if not root:
                    fail("Set the live web root first (option 2).")
                last_backup = do_backup(ftp, root)
            elif choice == "4":
                if not staging:
                    fail("Set the live web root first (option 2).")
                do_upload(ftp, staging)
                print(f"Verify staging in a browser: https://liardominoes.gt.tc/_staging/")
            elif choice == "5":
                if not root or not staging:
                    fail("Set the live web root first (option 2).")
                if last_backup is None:
                    answer = input("No backup made in this session. Backup path (blank to abort): ").strip()
                    last_backup = Path(answer) if answer else None
                    if last_backup is None:
                        fail("Promotion aborted: make or identify a backup first.")
                confirm = input(f"Promote {staging} -> {root}? type PROMOTE to continue: ").strip()
                if confirm != "PROMOTE":
                    print("Promotion cancelled.")
                    continue
                do_promote(ftp, staging, root)
            elif choice == "6":
                if not root:
                    fail("Set the live web root first (option 2).")
                answer = input(f"Backup folder [{last_backup or 'required'}]: ").strip()
                backup = Path(answer) if answer else last_backup
                if backup is None:
                    fail("A backup folder is required for rollback.")
                confirm = input(f"Restore {backup} over {root}? type ROLLBACK to continue: ").strip()
                if confirm != "ROLLBACK":
                    print("Rollback cancelled.")
                    continue
                do_rollback(ftp, backup, root)
            elif choice == "7":
                print("Disconnecting.")
                break
            else:
                print("Unknown option.")
    finally:
        try:
            ftp.quit()
        except Exception:
            try:
                ftp.close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
