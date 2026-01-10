# Package initialization and cleanup functions

.onLoad <- function(libname, pkgname) {
  # Set up ONNX Runtime library path when package is loaded
  setup_onnx_runtime()
}

.onAttach <- function(libname, pkgname) {
  # Display package startup message
  packageStartupMessage("churon: ONNX Runtime Integration for R")

  # Check if ONNX Runtime is properly configured
  if (!check_onnx_runtime_available()) {
    packageStartupMessage("")
    packageStartupMessage("ONNX Runtime is not installed.")
    packageStartupMessage("To install, run: install_onnx_runtime()")
    packageStartupMessage("")
  } else {
    packageStartupMessage("ONNX Runtime loaded successfully.")
  }
}

#' Setup ONNX Runtime Library Path
#'
#' This function sets up the ONNX Runtime library path for the current session.
#' It looks for the ONNX Runtime library in the package installation directory.
#'
#' @return Logical indicating whether setup was successful
#' @keywords internal
setup_onnx_runtime <- function() {
  lib_path <- onnx_runtime_lib_path()

  if (!file.exists(lib_path)) {
    # ONNX Runtime not found - environment variable set to empty
    Sys.setenv(ORT_DYLIB_PATH = "")
    return(FALSE)
  }

  # Set environment variable for ONNX Runtime
  Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_path))

  # Also set library path for dynamic loading
  lib_dir <- dirname(lib_path)
  platform <- Sys.info()["sysname"]

  # Add to library path based on platform
  if (platform == "Darwin") {
    # macOS: Add to DYLD_LIBRARY_PATH
    current_path <- Sys.getenv("DYLD_LIBRARY_PATH")
    if (nchar(current_path) > 0) {
      new_path <- paste(lib_dir, current_path, sep = ":")
    } else {
      new_path <- lib_dir
    }
    Sys.setenv(DYLD_LIBRARY_PATH = new_path)
  } else if (platform == "Linux") {
    # Linux: Add to LD_LIBRARY_PATH
    current_path <- Sys.getenv("LD_LIBRARY_PATH")
    if (nchar(current_path) > 0) {
      new_path <- paste(lib_dir, current_path, sep = ":")
    } else {
      new_path <- lib_dir
    }
    Sys.setenv(LD_LIBRARY_PATH = new_path)
  } else if (platform == "Windows") {
    # Windows: Add to PATH
    current_path <- Sys.getenv("PATH")
    new_path <- paste(lib_dir, current_path, sep = ";")
    Sys.setenv(PATH = new_path)
  }

  TRUE
}

#' Check if ONNX Runtime is Available
#' 
#' This function checks if ONNX Runtime is properly configured and available.
#' 
#' @return Logical indicating whether ONNX Runtime is available
#' @export
check_onnx_runtime_available <- function() {
  ort_path <- Sys.getenv("ORT_DYLIB_PATH")
  if (nchar(ort_path) == 0) {
    return(FALSE)
  }
  return(file.exists(ort_path))
}

#' Get ONNX Runtime Information
#' 
#' This function returns information about the current ONNX Runtime configuration.
#' 
#' @return A list containing ONNX Runtime configuration information
#' @export
get_onnx_runtime_info <- function() {
  list(
    dylib_path = Sys.getenv("ORT_DYLIB_PATH"),
    include_path = Sys.getenv("ORT_INCLUDE_PATH"),
    lib_path = Sys.getenv("ORT_LIB_PATH"),
    available = check_onnx_runtime_available(),
    platform = Sys.info()["sysname"],
    architecture = Sys.info()["machine"]
  )
}