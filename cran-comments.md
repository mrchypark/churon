## Test environments

* GitHub Actions: R-devel, R-release, and R 4.0 on Ubuntu (without ONNX
  Runtime and without network access during package installation)
* GitHub Actions: R-release on Ubuntu x86_64 and arm64, macOS, and Windows
* r-universe: R-devel, R-release, and R-oldrel native builders, plus WebAssembly

## R CMD check results

0 errors | 0 warnings | 0 notes

## Additional notes

This is a new submission.

Rust dependencies are vendored in the source package for offline builds. ONNX
Runtime is not bundled; users may download it explicitly with
`install_onnx_runtime()`. Tests that require it are skipped when it is absent.
