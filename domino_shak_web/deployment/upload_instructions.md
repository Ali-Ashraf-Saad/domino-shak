# Upload instructions (FTPS only)

These instructions are for the authorised deployment step. No credentials are
stored in this repository.

1. Obtain the FTP username and password through a secure hidden terminal
   prompt, never through chat or command-line arguments.
2. Connect with **explicit FTPS** to `ftpupload.net:21`. Do not fall back to
   unencrypted FTP. Verify the server certificate before transferring files.
3. Inspect the remote directory tree. Determine the real document root for
   `liardominoes.gt.tc`; it may be `htdocs` or a domain-specific directory.
4. Download the complete existing document root to a timestamped backup under
   `/home/ali/Documents/DominoGame/backups/` and verify file count, sizes and
   checksums before changing anything.
5. Upload the generated site to a staging directory first:
   `domino_shak_staging/`.
6. Verify staging in a browser: page load, fonts, PeerJS script, room create,
   join with `?room=CODE`, and no blocking console errors.
7. Only after staging passes, replace the required public-root files. Preserve
   unrelated files.
8. Confirm `https://liardominoes.gt.tc/` and
   `https://liardominoes.gt.tc/.well-known/assetlinks.json` behaviour.

Current blockers:

- FTP credentials were not available at audit time.
- Direct JSON serving for `.well-known/` is blocked by the current JavaScript
  cookie challenge until the host is configured or verified otherwise.
- The production `assetlinks.json` needs the real Play App Signing fingerprint,
  which is not available until Play enrollment.
