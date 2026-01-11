# Setup Development Environment
# Run this script to install all dependencies required for development and testing

setup_dev_env <- function() {
  # CRAN mirror
  r_repo <- "https://cloud.r-project.org"
  
  # Helper to install if missing
  install_if_missing <- function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message(sprintf("Installing %s...", pkg))
      install.packages(pkg, repos = r_repo)
    }
  }
  
  # Core dev tools
  install_if_missing("devtools")
  install_if_missing("testthat")
  install_if_missing("roxygen2")
  install_if_missing("rcmdcheck")
  
  # Rust interop
  install_if_missing("rextendr")
  
  # Documentation
  install_if_missing("knitr")
  install_if_missing("rmarkdown")
  
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
      message(sprintf("Found ONNX Runtime at: %s", churon:::onnx_runtime_lib_path()))
    } else {
      warning("ONNX Runtime not installed. Run churon::install_onnx_runtime()")
    }
  }
  
  message("Development environment setup complete!")
}

if (!interactive()) {
  setup_dev_env()
}
