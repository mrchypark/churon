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
    packageStartupMessage("Warning: ONNX Runtime may not be properly configured.")
    packageStartupMessage("Some functions may not work correctly.")
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
  # Try to find ONNX Runtime in package installation
  pkg_path <- system.file(package = "churon")
  
  # Look for ONNX Runtime in inst/onnxruntime directory
  ort_dir <- file.path(pkg_path, "onnxruntime")
  if (dir.exists(ort_dir)) {
    # Determine library name based on platform
    lib_name <- switch(Sys.info()["sysname"],
      "Linux" = "libonnxruntime.so",
      "Darwin" = "libonnxruntime.dylib",
      "Windows" = "onnxruntime.dll",
      "libonnxruntime.so"  # default
    )
    
    lib_path <- file.path(ort_dir, "lib", lib_name)
    
    if (file.exists(lib_path)) {
      # Set environment variable for ONNX Runtime
      Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_path))
      
      # Also set library path for dynamic loading
      lib_dir <- dirname(lib_path)
      
      # Add to library path based on platform
      if (Sys.info()["sysname"] == "Darwin") {
        # macOS: Add to DYLD_LIBRARY_PATH
        current_path <- Sys.getenv("DYLD_LIBRARY_PATH")
        if (nchar(current_path) > 0) {
          new_path <- paste(lib_dir, current_path, sep = ":")
        } else {
          new_path <- lib_dir
        }
        Sys.setenv(DYLD_LIBRARY_PATH = new_path)
      } else if (Sys.info()["sysname"] == "Linux") {
        # Linux: Add to LD_LIBRARY_PATH
        current_path <- Sys.getenv("LD_LIBRARY_PATH")
        if (nchar(current_path) > 0) {
          new_path <- paste(lib_dir, current_path, sep = ":")
        } else {
          new_path <- lib_dir
        }
        Sys.setenv(LD_LIBRARY_PATH = new_path)
      } else if (Sys.info()["sysname"] == "Windows") {
        # Windows: Add to PATH
        current_path <- Sys.getenv("PATH")
        new_path <- paste(lib_dir, current_path, sep = ";")
        Sys.setenv(PATH = new_path)
      }
      
      return(TRUE)
    }
  }
  
  # If we couldn't find ONNX Runtime in package, try system installation
  return(FALSE)
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