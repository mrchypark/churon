#' Install ONNX Runtime
#'
#' Download and install ONNX Runtime library for your platform.
#' This is required before using the churon package if ONNX Runtime
#' is not already installed on your system.
#'
#' @param version Character string specifying the ONNX Runtime version to install.
#'   Defaults to "1.23.0". Use "latest" to download the latest stable version.
#' @param quiet Logical. If TRUE, suppress download progress messages.
#' @param ... Additional arguments passed to download.file()
#'
#' @return Invisible TRUE on success, stops with error on failure.
#' @export
#' @examples
#' \dontrun{
#' # Install ONNX Runtime
#' install_onnx_runtime()
#'
#' # Install specific version
#' install_onnx_runtime(version = "1.23.0")
#'
#' # Install with no output
#' install_onnx_runtime(quiet = TRUE)
#' }
install_onnx_runtime <- function(version = "1.23.0", quiet = FALSE, ...) {
  # Platform detection
  platform <- Sys.info()[["sysname"]]
  machine <- Sys.info()[["machine"]]
  arch <- if (machine %in% c("arm64", "aarch64")) "arm64" else "x64"

  # Determine download URL
  ort_version <- if (identical(tolower(version), "latest")) {
    "1.23.0"  # Default to known working version for now
  } else {
    version
  }

  # Construct URL based on platform
  if (platform == "Linux") {
    if (arch == "arm64") {
      ort_arch <- "aarch64"
    } else {
      ort_arch <- "x64"
    }
    ort_archive <- sprintf("onnxruntime-linux-%s-%s.tgz", ort_arch, ort_version)
    ort_url <- sprintf("https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
                       ort_version, ort_archive)
  } else if (platform == "Darwin") {
    if (arch == "arm64") {
      ort_archive <- sprintf("onnxruntime-osx-arm64-%s.tgz", ort_version)
    } else {
      ort_archive <- sprintf("onnxruntime-osx-x86_64-%s.tgz", ort_version)
    }
    ort_url <- sprintf("https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
                       ort_version, ort_archive)
  } else if (platform == "Windows") {
    if (arch == "arm64") {
      ort_archive <- sprintf("onnxruntime-win-arm64-%s.zip", ort_version)
    } else {
      ort_archive <- sprintf("onnxruntime-win-x64-%s.zip", ort_version)
    }
    ort_url <- sprintf("https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
                       ort_version, ort_archive)
  } else {
    stop(sprintf("Unsupported platform: %s", platform))
  }

  # Create temporary directory for download
  temp_dir <- tempfile("onnxruntime")
  dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

  if (platform == "Windows") {
    ort_file <- file.path(temp_dir, "onnxruntime.zip")
  } else {
    ort_file <- file.path(temp_dir, ort_archive)
  }

  # Download
  if (!quiet) {
    message(sprintf("Downloading ONNX Runtime %s for %s-%s...", ort_version, platform, arch))
    message(sprintf("URL: %s", ort_url))
  }

  tryCatch({
    if (platform == "Windows") {
      utils::download.file(ort_url, ort_file, mode = "wb", quiet = quiet, ...)
    } else {
      utils::download.file(ort_url, ort_file, mode = "wb", quiet = quiet, ...)
    }

    # Extract
    if (!quiet) {
      message("Extracting...")
    }

    if (platform == "Windows") {
      utils::unzip(ort_file, exdir = temp_dir, quiet = TRUE)
    } else {
      utils::untar(ort_file, exdir = temp_dir, compressed = TRUE)
    }

    # Find the extracted directory
    extracted_dirs <- list.dirs(temp_dir, full.names = FALSE, recursive = FALSE)
    extracted_dir <- file.path(temp_dir, extracted_dirs[grepl("onnxruntime", extracted_dirs)])

    if (length(extracted_dir) == 0 || !dir.exists(extracted_dir)) {
      # Try to find the extracted files directly
      extracted_dir <- temp_dir
    }

    # Determine library path
    lib_dir <- file.path(.libPaths()[1], "churon", "onnxruntime", "lib")

    # Create directory if needed
    if (!dir.exists(lib_dir)) {
      dir.create(lib_dir, showWarnings = FALSE, recursive = TRUE)
    }

    # Copy library files
    if (!quiet) {
      message(sprintf("Installing to %s...", lib_dir))
    }

    # Copy lib directory
    lib_src_dir <- file.path(extracted_dir, "lib")
    if (dir.exists(lib_src_dir)) {
      file.copy(list.files(lib_src_dir, full.names = TRUE),
                lib_dir, overwrite = TRUE)
    }

    # Copy include directory (for future use)
    include_dir <- file.path(.libPaths()[1], "churon", "onnxruntime", "include")
    if (!dir.exists(include_dir)) {
      dir.create(include_dir, showWarnings = FALSE, recursive = TRUE)
    }
    include_src_dir <- file.path(extracted_dir, "include")
    if (dir.exists(include_src_dir)) {
      file.copy(list.files(include_src_dir, full.names = TRUE, recursive = TRUE),
                include_dir, overwrite = TRUE, recursive = TRUE)
    }

    # Clean up
    unlink(temp_dir, recursive = TRUE)

    # Verify installation
    lib_file <- onnx_runtime_lib_path()
    if (!file.exists(lib_file)) {
      stop("Installation verification failed: library file not found")
    }

    if (!quiet) {
      message(sprintf("ONNX Runtime installed successfully!"))
      message(sprintf("Library: %s", lib_file))
    }

    # Return success
    invisible(TRUE)

  }, error = function(e) {
    unlink(temp_dir, recursive = TRUE)
    stop(sprintf("Failed to install ONNX Runtime: %s", e$message))
  })
}

#' Check if ONNX Runtime is Installed
#'
#' Check if the ONNX Runtime library is installed and available.
#'
#' @return Logical indicating whether ONNX Runtime is installed.
#' @export
#' @keywords internal
onnx_runtime_is_installed <- function() {
  lib_path <- onnx_runtime_lib_path()
  return(file.exists(lib_path))
}

#' Check if ONNX Runtime is Installed
#'
#' Check if the ONNX Runtime library is installed and available.
#'
#' @return Logical indicating whether ONNX Runtime is installed.
#' @export
#' @keywords internal
onnx_runtime_is_installed <- function() {
  lib_path <- onnx_runtime_lib_path()
  return(file.exists(lib_path))
}

#' Get ONNX Runtime Library Path
#'
#' Get the path to the ONNX Runtime library for the current platform.
#'
#' @return Character string with the library path.
#' @keywords internal
onnx_runtime_lib_path <- function() {
  platform <- Sys.info()[["sysname"]]
  pkg_path <- system.file(package = "churon")

  lib_name <- switch(platform,
    "Linux" = "libonnxruntime.so",
    "Darwin" = "libonnxruntime.dylib",
    "Windows" = "onnxruntime.dll",
    stop(sprintf("Unsupported platform: %s", platform))
  )

  file.path(pkg_path, "onnxruntime", "lib", lib_name)
}

#' Setup ONNX Runtime
#'
#' Internal function to set up ONNX Runtime when the package is loaded.
#' Checks if ONNX Runtime is installed and guides user if not.
#'
#' @keywords internal
setup_onnx_runtime <- function() {
  lib_path <- onnx_runtime_lib_path()

  if (!file.exists(lib_path)) {
    # ONNX Runtime not found - set up guidance message
    if (interactive()) {
      message("")
      message("============================================================")
      message("ONNX Runtime is not installed for churon package.")
      message("")
      message("To install, run:")
      message("  install_onnx_runtime()")
      message("")
      message("Or download manually from:")
      message("  https://github.com/microsoft/onnxruntime/releases")
      message("============================================================")
      message("")
    }

    # Set environment variable to help with error messages
    Sys.setenv(ORT_DYLIB_PATH = "")
    return(FALSE)
  }

  # Set environment variable
  Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_path))

  # Add to library path
  lib_dir <- dirname(lib_path)

  if (platform == "Darwin") {
    current_path <- Sys.getenv("DYLD_LIBRARY_PATH", unset = "")
    if (nchar(current_path) > 0) {
      new_path <- paste(lib_dir, current_path, sep = ":")
    } else {
      new_path <- lib_dir
    }
    Sys.setenv(DYLD_LIBRARY_PATH = new_path)
  } else if (platform == "Linux") {
    current_path <- Sys.getenv("LD_LIBRARY_PATH", unset = "")
    if (nchar(current_path) > 0) {
      new_path <- paste(lib_dir, current_path, sep = ":")
    } else {
      new_path <- lib_dir
    }
    Sys.setenv(LD_LIBRARY_PATH = new_path)
  } else if (platform == "Windows") {
    current_path <- Sys.getenv("PATH", unset = "")
    new_path <- paste(lib_dir, current_path, sep = ";")
    Sys.setenv(PATH = new_path)
  }

  TRUE
}
