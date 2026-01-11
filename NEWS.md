# churon 0.1.4

* PREPARE FOR CRAN SUBMISSION
* Added `creating-model-packages` vignette.
* Updated `cran-comments.md` with package size justification.
* Removed non-standard fields from `DESCRIPTION`.
* Cleaned up `.Rbuildignore`.

# churon 0.1.3

## New Features

### Core ONNX Runtime Integration
- **ONNX Session Management**: Complete implementation of RSession for model loading and management
- **Multiple Execution Providers**: Support for CPU, CUDA, TensorRT, DirectML, OneDNN, and CoreML
- **High-Performance Inference**: Rust-based implementation for optimal performance and memory safety

### R Interface Functions
- `onnx_session()`: Create ONNX Runtime sessions from model files
- `onnx_run()`: Execute inference with comprehensive input validation
- `onnx_input_info()` / `onnx_output_info()`: Retrieve model tensor metadata
- `onnx_providers()`: Query available and active execution providers
- `onnx_model_path()`: Get loaded model file path

### Example Model Support
- **Korean Text Processing**: Built-in support for Korean spacing (kospacing) models
- `onnx_example_models()`: List available example models in package
- `find_model_path()`: Flexible model path resolution
- `onnx_example_session()`: Quick session creation with example models

### Error Handling and Validation
- **Comprehensive Input Validation**: Multi-layer validation at both Rust and R levels
- **Detailed Error Messages**: Context-aware error messages with solution suggestions
- **Safe Function Variants**: `safe_onnx_session()` and `safe_onnx_run()` with try/catch handling
- `check_onnx_runtime()`: Runtime environment availability checking

### Data Conversion System
- **Multi-Type Support**: Conversion between R data types and ndarray (f32, f64, i32, i64)
- **Shape Validation**: Automatic tensor shape validation against model requirements
- **Memory Efficient**: Optimized data conversion with minimal copying

### Documentation and Examples
- **Comprehensive Documentation**: Full roxygen2 documentation for all functions
- **Usage Examples**: Extensive examples covering common use cases
- **Error Handling Guide**: Complete guide for robust error handling patterns
- **Vignette**: Detailed introduction and tutorial

## Technical Implementation

### Rust Backend
- Built with extendr for seamless R-Rust integration
- Uses ort crate (v1.13.0+) for ONNX Runtime bindings
- Memory-safe implementation with comprehensive error handling
- Support for dynamic tensor dimensions and batch processing

### R Frontend
- Intuitive API design following R conventions
- Consistent error handling across all functions
- Comprehensive input validation and type checking
- Integration with R's native data structures

## System Requirements

- R (>= 4.0.0)
- ONNX Runtime (>= 1.13.0)
- Rust toolchain (for building from source)

## Known Limitations

- ONNX Runtime library must be installed separately
- Some advanced ONNX features may not be fully supported
- Tensor conversion implementation is still being optimized

## Installation

```r
# Install from source (development version)
devtools::install_github("churon-project/churon")
```

## Getting Started

```r
library(churon)

# Check ONNX Runtime availability
if (check_onnx_runtime()) {
  # Load example model
  session <- onnx_example_session("kospacing")
  
  # Get model information
  input_info <- onnx_input_info(session)
  print(input_info)
} else {
  cat("Please install ONNX Runtime first\n")
}
```