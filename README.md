# churon

<!-- badges: start -->
[![R-CMD-check](https://github.com/churon-project/churon/workflows/R-CMD-check/badge.svg)](https://github.com/churon-project/churon/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/churon)](https://CRAN.R-project.org/package=churon)
<!-- badges: end -->

**churon** is an R package that provides high-performance ONNX Runtime integration for machine learning inference, with specialized support for Korean text processing models.

## Features

- **ONNX Runtime Integration**: Run ONNX models directly in R with full support for various execution providers
- **Korean Text Processing**: Built-in support for Korean spacing (kospacing) models
- **High Performance**: Built with Rust for memory safety and performance
- **Comprehensive Error Handling**: Robust validation and clear error messages
- **Multiple Execution Providers**: Support for CPU, CUDA, TensorRT, DirectML, OneDNN, and CoreML
- **Easy-to-Use API**: Simple and intuitive R interface

## Installation

### Prerequisites

You need to have ONNX Runtime installed on your system. The package supports ONNX Runtime version 1.13.0 or higher.

### Install from Source

```r
# Install development version from GitHub
# install.packages("devtools")
devtools::install_github("churon-project/churon")
```

## Quick Start

### Basic Usage

```r
library(churon)

# Check if ONNX Runtime is available
if (check_onnx_runtime()) {
  # Load an example model
  models <- onnx_example_models()
  print(models)
  
  # Create a session
  session <- onnx_session(models["kospacing"])
  
  # Get model information
  input_info <- onnx_input_info(session)
  output_info <- onnx_output_info(session)
  
  print("Input information:")
  print(input_info)
  
  print("Output information:")
  print(output_info)
  
  # Run inference (example with dummy data)
  # inputs <- list(input_tensor = your_input_data)
  # result <- onnx_run(session, inputs)
} else {
  cat("ONNX Runtime is not available. Please install ONNX Runtime.\n")
}
```

### Safe Usage with Error Handling

```r
library(churon)

# Safe session creation
session <- safe_onnx_session("path/to/model.onnx")
if (!is.null(session)) {
  cat("Session created successfully\n")
  
  # Safe inference
  inputs <- list(input_tensor = matrix(rnorm(100), nrow = 10))
  result <- safe_onnx_run(session, inputs)
  
  if (!is.null(result)) {
    cat("Inference completed successfully\n")
    print(result)
  }
}
```

### Working with Korean Text Models

```r
library(churon)

# Use Korean spacing model
session <- onnx_example_session("kospacing")

# The kospacing model expects specific input format
# (This is just an example - actual usage depends on model requirements)
# text_input <- prepare_korean_text("한국어텍스트처리예제")
# result <- onnx_run(session, list(input = text_input))
```

## API Reference

### Core Functions

- `onnx_session(model_path, providers = NULL)`: Create ONNX session
- `onnx_run(session, inputs)`: Run inference
- `onnx_input_info(session)`: Get input tensor information
- `onnx_output_info(session)`: Get output tensor information
- `onnx_providers(session)`: Get execution providers
- `onnx_model_path(session)`: Get model file path

### Example Model Functions

- `onnx_example_models()`: List available example models
- `find_model_path(model_name)`: Find model file path
- `onnx_example_session(model_name)`: Create session with example model

### Safe Functions

- `safe_onnx_session(model_path, silent = FALSE)`: Safe session creation
- `safe_onnx_run(session, inputs, silent = FALSE)`: Safe inference
- `check_onnx_runtime()`: Check ONNX Runtime availability

## Execution Providers

churon supports multiple execution providers for optimal performance:

- **CPU**: Default CPU execution
- **CUDA**: NVIDIA GPU acceleration
- **TensorRT**: NVIDIA TensorRT optimization
- **DirectML**: DirectX Machine Learning (Windows)
- **OneDNN**: Intel OneDNN optimization
- **CoreML**: Apple CoreML (macOS)

```r
# Specify execution providers
session <- onnx_session("model.onnx", providers = c("cuda", "cpu"))
```

## Error Handling

The package provides comprehensive error handling with clear messages:

```r
# Example error handling patterns
tryCatch({
  session <- onnx_session("model.onnx")
  result <- onnx_run(session, inputs)
}, error = function(e) {
  if (grepl("ONNX Runtime library not found", e$message)) {
    cat("Please install ONNX Runtime\n")
  } else if (grepl("Required input.*not provided", e$message)) {
    cat("Check model input requirements with onnx_input_info()\n")
  } else {
    cat("Error:", e$message, "\n")
  }
})
```

## System Requirements

- R (>= 4.0.0)
- ONNX Runtime (>= 1.13.0)
- Rust toolchain (for building from source)

### Installing ONNX Runtime

Please refer to the [ONNX Runtime installation guide](https://onnxruntime.ai/docs/install/) for your platform.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [extendr](https://github.com/extendr/extendr) for R-Rust integration
- Uses [ONNX Runtime](https://onnxruntime.ai/) for machine learning inference
- Includes Korean spacing models for text processing