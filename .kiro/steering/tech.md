# Technology Stack

## Core Technologies
- **R**: Primary interface language with roxygen2 documentation
- **Rust**: Core implementation using Rust 2021 edition
- **extendr**: R-Rust FFI bridge (version 0.4.0)
- **ONNX Runtime**: ML inference engine (ort crate v1.15.0)

## Key Dependencies
- `ndarray` (0.15.6): N-dimensional array handling
- `ort`: ONNX Runtime bindings with dynamic loading
- `extendr-api`: R integration with ndarray features

## Build System
- **R Package**: Standard R package structure with DESCRIPTION, NAMESPACE
- **Rust**: Cargo-based build with staticlib crate type
- **Integration**: C entrypoint for R-Rust registration

## Execution Providers
Support for multiple ML acceleration backends:
- CUDA, TensorRT, DirectML, OneDNN, CoreML, CPU

## Common Commands
```bash
# R package development
R CMD build .
R CMD check .
R CMD INSTALL .

# Rust development (in src/rust/)
cargo build
cargo test
cargo check
```

## Configuration
- Uses rextendr for R-Rust integration (Config/rextendr/version: 0.3.1)
- Static library compilation for R integration
- Dynamic ONNX Runtime loading