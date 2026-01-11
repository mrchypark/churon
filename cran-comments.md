## R CMD check results

0 errors | 2 warnings | 3 notes

### Warnings

*   **Compiled code**: "Found '__exit', possibly from '_exit' (C)..." and "Found non-API calls to R...".
    *   These are standard warnings for R packages using Rust via `extendr`. The exit/abort symbols are part of the Rust standard library's panic handling mechanisms. The non-API calls are used by `extendr` to interface with R's internal structures for performance and functionality not yet available in the public C API. We ensure these are used safely. This is consistent with other Rust-based CRAN packages (e.g., `gifski`, `string2path`).

*   **Rust compilation**: "Downloads Rust crates" / "No rustc version reported".
    *   The "Downloads crates" warning is a false positive in the log analysis; we vendor all Rust dependencies for CRAN submission using `rextendr::vendor_pkgs()`. The build process uses these vendored crates offline.

### Notes

*   **Size of tarball (approx. 27MB)**:
    *   The package size is due to the inclusion of vendored Rust dependencies (specifically `ort` and `ndarray`), which is required for offline compilation on CRAN.
    *   This is a known characteristic of Rust-based R packages on CRAN. For comparison:
        *   `gifski`: ~7.2 MB (smaller dependency tree)
        *   `torch`: ~1.9 MB (uses external libtorch download script, whereas we vendor core logic for stability)
        *   `churon` aims to be a self-contained runtime wrapper like `gifski` but for ONNX, necessitating larger crate dependencies. We have optimized the dependency tree as much as possible.

*   **CRAN incoming feasibility**:
    *   `VignetteBuilder`: Package uses knitr. A vignette "Creating R Packages with ONNX Runtime" is included to demonstrate usage.

*   **Non-standard files/directories**:
    *   All development-related files (`AGENTS.md`, `tools/`, etc.) have been added to `.Rbuildignore` and should no longer appear in the tarball.

*   **Hidden files**: `.sisyphus` is excluded from the build.
