# churon: ONNX Runtime Integration for R

[![R-CMD-check](https://github.com/churon-project/churon/workflows/R-CMD-check/badge.svg)](https://github.com/churon-project/churon/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

churon provides R bindings for ONNX Runtime, enabling high-performance machine learning inference with ONNX models.

## Features

- 🚀 **High Performance**: Core logic implemented in Rust for speed
- 🛡️ **Memory Safety**: Rust's memory safety guarantees
- 🔧 **Comprehensive Error Handling**: Detailed error messages and validation
- 🌐 **Multiple Execution Providers**: CUDA, TensorRT, DirectML, OneDNN, CoreML, CPU support
- 📦 **Bundled Example Models**: MNIST included for testing

## Installation

### System Requirements

- R (>= 4.0.0)
- Rust (>= 1.70.0)
- ONNX Runtime (>= 1.13.0) - automatically downloaded

### Install from GitHub

```r
# Install from GitHub
devtools::install_github("churon-project/churon")

# Or build from source
R CMD build .
R CMD INSTALL churon_0.0.1.tar.gz
```

## Quick Start

### Basic Usage

```r
library(churon)

# Check available example models
models <- onnx_example_models()
print(models)
# mnist.onnx
# "/path/to/churon/model/mnist.onnx"

# Create a session with the example MNIST model
session <- onnx_example_session("mnist")

# Get model information
input_info <- onnx_input_info(session)
output_info <- onnx_output_info(session)

print(input_info[[1]]$get_name())     # Input tensor name
print(input_info[[1]]$get_shape())    # Input tensor shape
print(input_info[[1]]$get_data_type()) # Input tensor data type

# Run inference
input_name <- input_info[[1]]$get_name()
input_shape <- input_info[[1]]$get_shape()  # c(1, 1, 28, 28) for MNIST

# Create random input (28x28 grayscale image)
input_data <- array(rnorm(prod(input_shape)), dim = input_shape)
result <- onnx_run(session, setNames(list(input_data), input_name))

# Result is class probabilities
cat("Predicted digit:", which.max(result[[1]]) - 1, "\n")
```

### Using Custom ONNX Models

```r
library(churon)

# Load any ONNX model
session <- onnx_session("path/to/your/model.onnx")

# Get expected input/output information
input_info <- onnx_input_info(session)
output_info <- onnx_output_info(session)

# Run inference with your data
inputs <- list()
inputs[[input_info[[1]]$get_name()]] <- your_data
outputs <- onnx_run(session, inputs)
```

### Session Management

```r
# Create session with specific providers
session <- onnx_session("model.onnx", providers = c("cuda", "cpu"))

# Get available providers
providers <- onnx_providers(session)
cat("Available providers:", paste(providers, collapse = ", "), "\n")

# Get model path
model_path <- onnx_model_path(session)
```

### Safe Session Creation with Error Handling

```r
# Safe session creation with automatic error handling
session <- safe_onnx_session("model.onnx", optimize = TRUE)

if (!is.null(session)) {
  # Session created successfully
  result <- onnx_run(session, inputs)
} else {
  cat("Failed to create session\n")
}

# Safe inference with monitoring
result <- safe_onnx_run(session, inputs, monitor_performance = TRUE)
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `onnx_session(model_path, providers = NULL)` | Create an ONNX Runtime session |
| `onnx_run(session, inputs)` | Run inference with input data |
| `onnx_input_info(session)` | Get input tensor information |
| `onnx_output_info(session)` | Get output tensor information |
| `onnx_providers(session)` | Get available execution providers |

### Example Models

| Function | Description |
|----------|-------------|
| `onnx_example_models()` | List bundled example models |
| `onnx_example_session(model_name)` | Create session with example model |

### Utility Functions

| Function | Description |
|----------|-------------|
| `find_model_path(model_name)` | Find full path to a model file |
| `get_onnx_runtime_info()` | Get ONNX Runtime version info |
| `check_onnx_runtime_available()` | Check if ONNX Runtime is available |
| `safe_onnx_session()` | Create session with error handling |
| `safe_onnx_run()` | Run inference with error handling |

## Performance Optimization

```r
session <- onnx_session("model.onnx")

# Optimize session for performance
optimize_session_performance(session)

# Warm up the session
session$warmup()

# Get performance statistics
stats <- get_session_performance_stats(session)

# Estimate memory usage
memory <- estimate_session_memory(session)
```

## Batch Processing

```r
# Process large datasets in batches
session <- onnx_session("model.onnx")
data_list <- list(batch1, batch2, batch3, ...)  # Your data batches

results <- batch_process_data(session, data_list, batch_size = 32)
```

## Current Status

### ✅ Fully Working Features

- ONNX model loading and session management
- Model metadata extraction and querying
- Complete tensor conversion and inference execution
- Multiple execution provider support
- Comprehensive error handling
- Utility functions

### ⚠️ Limitations

- **Tensor Types**: Currently supports f32 (float32) numeric tensors
- **Performance**: Basic optimization applied, advanced features limited
- **Documentation**: Some function documentation may be incomplete

## Development Roadmap

- [x] ONNX tensor conversion logic
- [x] Actual inference execution
- [x] Bundled example models (MNIST)
- [ ] Additional tensor type support (int64, etc.)
- [ ] Advanced performance optimization
- [ ] Comprehensive documentation

## Contributing

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [ONNX Runtime](https://onnxruntime.ai/) team
- [extendr](https://github.com/extendr/extendr) project
- R community
