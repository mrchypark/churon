## Resubmission (0.1.12)

This resubmission addresses the CRAN review of version 0.1.11:

* Removed the redundant "for R" from the title and quoted software names
  consistently; MNIST is no longer quoted.
* Added ONNX Runtime and GitHub release URLs to DESCRIPTION.
* Documented the return types and meaning of `$.TensorInfo` results.
* Replaced non-running placeholder examples with executable examples using
  the bundled MNIST model, conditional on runtime availability.
* Removed software installation calls from the installer examples.
* Required an explicit `destdir` for runtime installation. The installer no
  longer writes into the package library, and configures `ORT_DYLIB_PATH`
  for the current session. Later-session configuration is documented.
* Removed automatic R package installation from the development setup script.

## Local validation (2026-09-11)

* macOS arm64, R 4.5.2, Rust 1.97.1.
* Runtime-enabled tests: 90 passed, no failures, warnings, or skips.
* Offline `R CMD check --as-cran --no-manual`: 0 errors, 0 warnings, 1 note.
  The note reports that current time could not be verified with network access
  disabled. The official Debian `checkbashisms` utility was supplied for this check.
  Package installation, documentation, examples, and tests passed.

## Additional notes

Rust dependencies are vendored in the source package for offline builds.
ONNX Runtime is not bundled. The dedicated installer downloads it only on
explicit request with a user-supplied destination. Tests requiring a runtime
are skipped when it is absent; tests do not download or install software.

## Submission status

Version 0.1.12 was uploaded and submitted through the CRAN web form on
2026-09-11 (upload ID 354755). The maintainer subsequently confirmed publication on CRAN.
The Git repository is being synchronized with the published 0.1.12 release.
