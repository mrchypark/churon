# Setup Development Environment
# Run this script to check dependencies required for development and testing

setup_dev_env <- function() {
  packages <- c(
    "devtools",
    "testthat",
    "roxygen2",
    "rcmdcheck",
    "rextendr",
    "knitr",
    "rmarkdown"
  )
  missing <- packages[
    !vapply(packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing)) {
    stop(
      "Install these development dependencies before continuing: ",
      paste(missing, collapse = ", ")
    )
  }

  # Check for system dependencies
  message("Checking system requirements...")

  # Check Rust
  rust_version <- tryCatch(
    system("rustc --version", intern = TRUE),
    error = function(e) NULL,
    warning = function(w) NULL
  )

  if (is.null(rust_version)) {
    warning("Rust compiler (rustc) not found. Please install Rust.")
  } else {
    message(sprintf("Found Rust: %s", rust_version))
  }

  # Check ONNX Runtime
  if (requireNamespace("churon", quietly = TRUE)) {
    if (churon:::onnx_runtime_is_installed()) {
      message(sprintf(
        "Found ONNX Runtime at: %s",
        churon:::onnx_runtime_lib_path()
      ))
    } else {
      warning(
        "ONNX Runtime not installed. Run churon::install_onnx_runtime(destdir = tempdir())"
      )
    }
  }

  message("Development environment setup complete!")
}

if (!interactive()) {
  setup_dev_env()
}
