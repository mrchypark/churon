# Agent Guide for churon

This repository hosts an R package with Rust bindings for ONNX Runtime, using the `extendr` framework.
Follow these guidelines to work effectively in this hybrid R/Rust environment.

## 🛠 Build & Test Commands

### Prerequisites
- **R** (>= 4.0.0)
- **Rust** (>= 1.75.0)
- **ONNX Runtime**: Must be installed via `install_onnx_runtime()` (R) or manually placed in `inst/onnxruntime/`.

### R Development (Primary)
Use `devtools` for most R-side operations.

- **Load Package (Dev Mode)**:
  ```r
  devtools::load_all()
  ```
  *Note: This automatically builds the Rust library if source files changed.*

- **Run All Tests**:
  ```r
  devtools::test()
  ```

- **Run a Single Test File**:
  ```r
  testthat::test_file("tests/testthat/test-model-utilities.R")
  ```

- **Update Rust Wrappers**:
  If you modify `#[extendr]` signatures in Rust, regenerate R wrappers:
  ```r
  rextendr::document()
  ```

### Rust Development (Core Logic)
Work in `src/rust/` for core implementation logic.

- **Build Rust Lib**:
  ```bash
  # From src/rust directory
  cargo build --release
  ```

- **Run Rust Tests**:
  ```bash
  # From src/rust directory
  cargo test
  ```

- **Lint Rust**:
  ```bash
  cargo clippy
  ```

## 📐 Code Style & Conventions

### R Style (`R/`)
- Follow the **Tidyverse Style Guide**.
- **Naming**: `snake_case` for functions and variables.
- **Prefix**: Public functions should start with `onnx_`.
- **Indentation**: 2 spaces.
- **Documentation**: Use `roxygen2` comments (`#'`).

### Rust Style (`src/rust/`)
- Follow standard Rust conventions (`rustfmt`).
- **Naming**: `SnakeCase` for structs/traits, `snake_case` for functions/variables.
- **Error Handling**:
  - Use `ChurOnError` enum for all internal errors.
  - Implement `From<ChurOnError> for extendr_api::Error`.
  - **Never panic** in FFI code; use `Result<T, ChurOnError>`.

### R-Rust Interop (extendr)
- **Structs**: Wrap internal logic in structs (e.g., `RSession`).
- **Exposed Methods**: Use `#[extendr]` macro on `impl` blocks.
- **Data Conversion**:
  - Use `DataConverter` (in `lib.rs`) for converting R objects to `ndarray`.
  - Avoid raw pointer manipulation; use `extendr_api` safe wrappers.

## 📦 CRAN Submission Guidelines

To ensure this package meets CRAN policies (especially for Rust):

1.  **System Requirements**:
    Ensure `DESCRIPTION` contains:
    ```dcf
    SystemRequirements: Cargo (Rust's package manager), rustc
    ```

2.  **Offline Build (Vendoring)**:
    CRAN build servers do not have internet access. Rust dependencies must be vendored inside the package source tarball.
    - **Development**: Do not commit `vendor/` to git.
    - **Release**: Run `rextendr::vendor_pkgs()` before building the source tarball.
    - **Note**: Ensure `.Rbuildignore` does *not* ignore `src/rust/vendor` when building for CRAN.

3.  **Binary Size Limits**:
    CRAN has a 5MB size limit.
    - **Do NOT bundle** `libonnxruntime` or `mnist.onnx` in the CRAN source package if they exceed this.
    - The current strategy of `install_onnx_runtime()` (downloading on user request) is CRAN-compliant, provided the package functions gracefully fail or warn when the library is missing, rather than crashing.

4.  **Compilation Time**:
    Rust compilation must be fast (< 10 mins).
    - Use `profile.release` in `Cargo.toml` to optimize for size/speed trade-offs if needed.
    - `opt-level = 2` is often a good balance for CRAN.

5.  **Testing on CRAN**:
    Tests requiring the downloaded ONNX Runtime or external models must be skipped if the resource is missing.
    ```r
    test_that("inference works", {
      skip_if_not(onnx_runtime_is_installed())
      # ... test code ...
    })
    ```

## ⚠️ Critical Constraints

1.  **ONNX Runtime Dependency**:
    - The package depends on dynamic libraries (`libonnxruntime`).
    - **Do not commit** large binary files (DLLs/dylibs) to git.
    - Ensure `ORT_DYLIB_PATH` is handled in `R/zzz.R`.

2.  **Memory Safety**:
    - Rust handles memory for tensors.
    - Be careful with `&str` vs `String` across the FFI boundary.

3.  **Git Workflow**:
    - Commit `R/extendr-wrappers.R` only if you ran `rextendr::document()`.
    - Do not commit `src/rust/target/`.

## 📂 Project Structure

- `R/` - R source code.
  - `onnx_interface.R`: Main user-facing API.
  - `extendr-wrappers.R`: Auto-generated bindings.
- `src/rust/` - Rust crate.
  - `src/lib.rs`: Core logic and FFI export.
- `inst/`
  - `onnxruntime/`: Location for downloaded runtime libs.
  - `model/`: Example models (MNIST).
- `tools/` - Helper scripts for downloading dependencies.
