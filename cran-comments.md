## Update (0.1.13)

This update fixes the installation failures reported by the CRAN macOS
release/oldrel checks and the additional M1mac check for version 0.1.12.

`configure` successfully finds Cargo and rustc under `~/.cargo/bin`, but the
Makevars recipe ran a redundant `rustc --version` before adding that directory
to PATH. On the CRAN builders this failed with `rustc: No such file or directory`.

* Removed the redundant version commands from the Unix and Windows Makevars.
  `configure` continues to enforce Cargo and rustc >= 1.88.0.
* Applied the existing Unix Cargo PATH fallback to the Windows build as well.
* Added a macOS CI regression check with Cargo and rustc removed from PATH.

## Additional notes

Rust dependencies are vendored in the source package for offline builds.
ONNX Runtime is not bundled. The dedicated installer downloads it only on
explicit request with a user-supplied destination. Tests requiring a runtime
are skipped when it is absent; tests do not download or install software.
