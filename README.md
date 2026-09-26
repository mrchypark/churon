# churon

[![CRAN version](https://www.r-pkg.org/badges/version/churon)](https://CRAN.R-project.org/package=churon)
[![R CMD Check](https://github.com/mrchypark/churon/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/mrchypark/churon/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)

Run ONNX models from R using [ONNX Runtime](https://onnxruntime.ai/).
churon provides model sessions, named tensor inputs and outputs, and a bundled
MNIST model through Rust bindings built with [extendr](https://extendr.github.io/).

## Install

Install the released package from [CRAN](https://CRAN.R-project.org/package=churon):

```r
install.packages("churon")
```

R 4.0.0 or later is required. Installing a binary package does not require Rust.
Building from source requires Cargo and rustc 1.88.0 or later, along with the
platform's R compilation tools. Rust dependencies are vendored in the CRAN
source package for offline compilation.

For alternative builds, use [R-universe](https://mrchypark.r-universe.dev/churon):

```r
install.packages(
  "churon",
  repos = c("https://mrchypark.r-universe.dev", "https://cloud.r-project.org")
)
```

## Set up ONNX Runtime

ONNX Runtime is a separate native library. The R package can load without it,
but inference requires it. Nothing is downloaded automatically.

For a first run, install the runtime into a temporary directory:

```r
library(churon)

install_onnx_runtime(destdir = file.path(tempdir(), "onnxruntime"))
check_onnx_runtime_available()
# TRUE
```

The installer requires an explicit destination, verifies the download's SHA-256
checksum, and sets `ORT_DYLIB_PATH` for the current R session. It supports runtime
versions 1.28.0 and 1.29.0; the default is 1.29.0.

To keep the runtime between sessions, choose a persistent directory instead of
`tempdir()`. After installation, inspect the library's full path:

```r
get_onnx_runtime_info()$dylib_path
```

In each new R session, set that path **before** loading churon. You can also set
`ORT_DYLIB_PATH` in your `.Renviron` file. It must point to the library file, not
its directory:

| Platform | Library under your installation directory |
| --- | --- |
| macOS ARM64 | `lib/libonnxruntime.dylib` |
| Linux x64 / ARM64 | `lib/libonnxruntime.so` |
| Windows x64 / ARM64 | `lib/onnxruntime.dll` |

An existing compatible ONNX Runtime installation can be used the same way,
without running the installer. Restart R before switching a runtime that has
already been loaded. The installer does not support Intel macOS.

## Run the bundled MNIST model

Once the runtime is configured, this example runs without any model downloads:

```r
session <- onnx_example_session("mnist")

# MNIST expects one grayscale image: batch x channel x height x width.
# A blank image demonstrates the API; it is not a useful recognition example.
image <- array(0, dim = c(1, 1, 28, 28))
input_name <- onnx_input_info(session)[[1]]$get_name()
inputs <- setNames(list(image), input_name)

outputs <- onnx_run(session, inputs)
scores <- as.numeric(outputs[[1]])
predicted_digit <- which.max(scores) - 1L
predicted_digit
```

Inputs are a named list of numeric vectors, matrices, or arrays. Names must
match the model's input names. Outputs are a named list of tensors; their
meaning depends on the model. The MNIST outputs are scores for digits 0–9,
not automatically normalized probabilities.

For real images, use the preprocessing and tensor layout expected by your
model. churon does not resize, normalize, or otherwise preprocess images.

## Use your own model

Replace the path and supply `input_data` with the dimensions and preprocessing
required by your model:

```r
session <- onnx_session("path/to/model.onnx")

input_info <- onnx_input_info(session)
output_info <- onnx_output_info(session)
print(input_info)
print(output_info)

# For a single-input model, after preparing input_data:
inputs <- setNames(list(input_data), input_info[[1]]$get_name())
outputs <- onnx_run(session, inputs)
```

For models with multiple inputs, provide one named list entry per input.
Use the model's specification for tensor dimensions: the current metadata
implementation returns `-1` as a shape placeholder, so do not construct arrays
from `$get_shape()`.

## API at a glance

| Function | Purpose |
| --- | --- |
| `onnx_session(model_path)` | Load a model into a session |
| `onnx_run(session, inputs)` | Run inference and return named output tensors |
| `onnx_input_info(session)` / `onnx_output_info(session)` | Inspect tensor metadata |
| `onnx_model_path(session)` | Get the session's model path |
| `onnx_providers(session)` | Get the session's reported execution providers |
| `onnx_example_models()` | List bundled model paths |
| `onnx_example_session("mnist")` | Load the bundled MNIST model |
| `install_onnx_runtime(destdir = ...)` | Explicitly download and install the runtime |
| `onnx_runtime_is_installed()` | Check whether a runtime library file can be found |
| `check_onnx_runtime_available()` | Check whether the configured runtime path exists |
| `get_onnx_runtime_info()` | Inspect runtime paths, platform, and configuration |
| `safe_onnx_session()` / `safe_onnx_run()` | Warn and return `NULL` on failure |
| `batch_process_data(session, data_list)` | Process a list of input sets in batches |

See `?onnx_session`, `?onnx_run`, and `?install_onnx_runtime` in R for details,
or read the [reference manual](https://CRAN.R-project.org/web/packages/churon/churon.pdf).

## Current limitations

- **CPU inference:** the current R session API uses CPU execution. Its
  `providers` argument validates names but does not yet select a backend;
  passing `"cuda"` does not enable GPU inference.
- **Tensor types:** the public inference API accepts numeric inputs and converts
  them to float32. Do not assume support for integer, boolean, string, or
  float64 model inputs.
- **Shape metadata:** reported shapes are placeholders. Supply dimensions from
  your model's specification.
- **Runtime checks:** path checks confirm that a file exists, not that it is a
  compatible library. Actual model loading can still fail.

## Troubleshooting

**Runtime not found:** inspect `get_onnx_runtime_info()`. Set `ORT_DYLIB_PATH`
to the full library filename before loading churon, or run the installer with
an explicit destination. Temporary installations disappear after the R session.

**Model or input errors:** check that the model file exists, input names match,
and tensor types and dimensions agree with the model. `onnx_run()` reports
errors; `safe_onnx_run()` turns them into warnings and returns `NULL`.

## Development and support

Report bugs or request features in
[GitHub issues](https://github.com/mrchypark/churon/issues). Include your OS,
R and churon versions, runtime configuration, and a minimal reproducible example.
Pull requests are welcome.

With the development dependencies and Rust toolchain installed, run from a
checkout:

```r
devtools::load_all()
devtools::test()
```

Tests requiring ONNX Runtime are skipped when it is unavailable.

## License

churon is licensed under [MIT](LICENSE.md). The bundled MNIST model and external
ONNX Runtime library have their own licensing terms; see
[third-party notices](inst/COPYRIGHTS) and [contributors](inst/AUTHORS).
