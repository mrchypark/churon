## R CMD check results

0 errors | 2 warnings | 3 notes

### Warnings

*   **Compiled code**: "Found '__exit', possibly from '_exit' (C)..." and "Found non-API calls to R...".
    *   These are standard warnings for R packages using Rust via `extendr`. The exit/abort symbols are part of the Rust standard library's panic handling mechanisms. The non-API calls are used by `extendr` to interface with R's internal structures for performance and functionality not yet available in the public C API. We ensure these are used safely.

*   **Rust compilation**: "Downloads Rust crates" / "No rustc version reported".
    *   The "Downloads crates" warning is a false positive in the log analysis; we vendor all Rust dependencies for CRAN submission using `rextendr::vendor_pkgs()`. The build process uses these vendored crates offline.

### Notes

*   **CRAN incoming feasibility**:
    *   `Remotes` field: Used for development dependencies (torch).
    *   `VignetteBuilder`: Package uses knitr for potential future vignettes, though none are currently included.
    *   `Size of tarball`: The package includes vendored Rust dependencies required for offline compilation, which increases the source package size.

*   **Non-standard files/directories**:
    *   `AGENTS.md`, `LICENSE.md`: Documentation files.
    *   `configure`: A standard configure script is provided.

*   **Hidden files**: `.sisyphus` is excluded from the build.
