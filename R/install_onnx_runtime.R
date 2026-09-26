#' Install ONNX Runtime
#'
#' Download and install ONNX Runtime library for your platform.
#' This is required before using the churon package if ONNX Runtime
#' is not already installed on your system.
#'
#' @param version Character string specifying the ONNX Runtime version to install.
#'   Defaults to "1.29.0". Supported versions are "1.28.0" and "1.29.0";
#'   "latest" selects "1.29.0".
#' @param destdir Required character string naming the installation directory.
#' @param quiet Logical. If TRUE, suppress download progress messages.
#' @param ... Additional arguments passed to download.file()
#'
#' @return Invisible TRUE on success, stops with error on failure.
#' @export
#' @details
#' This function installs external software only when explicitly called. Supply
#' `destdir` yourself; no installation directory is selected by default.
#' The library is placed in `destdir/lib` and configured for this R session.
#' In later sessions, set `ORT_DYLIB_PATH` to the installed library file before
#' loading churon. Restart R before switching an already loaded runtime.
install_onnx_runtime <- function(
  version = "1.29.0",
  quiet = FALSE,
  destdir,
  ...
) {
  if (!is.character(version) || length(version) != 1L || is.na(version)) {
    stop("version must be one non-missing character string.")
  }

  if (
    missing(destdir) ||
      !is.character(destdir) ||
      length(destdir) != 1L ||
      is.na(destdir) ||
      !nzchar(trimws(destdir))
  ) {
    stop("destdir must be supplied as one non-empty directory path.")
  }
  destdir <- path.expand(destdir)

  # Platform detection
  platform <- Sys.info()[["sysname"]]
  machine <- Sys.info()[["machine"]]
  arch <- if (machine %in% c("arm64", "aarch64")) "arm64" else "x64"

  # Determine download URL
  ort_version <- if (identical(tolower(version), "latest")) {
    "1.29.0"
  } else {
    version
  }
  if (!ort_version %in% c("1.28.0", "1.29.0")) {
    stop("This installer supports ONNX Runtime versions 1.28.0 and 1.29.0.")
  }

  # Construct URL based on platform
  if (platform == "Linux") {
    if (arch == "arm64") {
      ort_arch <- "aarch64"
    } else {
      ort_arch <- "x64"
    }
    ort_archive <- sprintf("onnxruntime-linux-%s-%s.tgz", ort_arch, ort_version)
    ort_url <- sprintf(
      "https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
      ort_version,
      ort_archive
    )
  } else if (platform == "Darwin") {
    if (arch != "arm64") {
      stop("ONNX Runtime >= 1.28.0 does not support macOS x86_64.")
    }
    ort_archive <- sprintf("onnxruntime-osx-arm64-%s.tgz", ort_version)
    ort_url <- sprintf(
      "https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
      ort_version,
      ort_archive
    )
  } else if (platform == "Windows") {
    if (arch == "arm64") {
      ort_archive <- sprintf("onnxruntime-win-arm64-%s.zip", ort_version)
    } else {
      ort_archive <- sprintf("onnxruntime-win-x64-%s.zip", ort_version)
    }
    ort_url <- sprintf(
      "https://github.com/microsoft/onnxruntime/releases/download/v%s/%s",
      ort_version,
      ort_archive
    )
  } else {
    stop(sprintf("Unsupported platform: %s", platform))
  }
  expected_sha256 <- .onnx_runtime_sha256(ort_version, ort_archive)

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
    message(sprintf(
      "Downloading ONNX Runtime %s for %s-%s...",
      ort_version,
      platform,
      arch
    ))
    message(sprintf("URL: %s", ort_url))
  }

  tryCatch(
    {
      if (platform == "Windows") {
        utils::download.file(ort_url, ort_file, mode = "wb", quiet = quiet, ...)
      } else {
        utils::download.file(ort_url, ort_file, mode = "wb", quiet = quiet, ...)
      }

      actual_sha256 <- digest::digest(
        ort_file,
        algo = "sha256",
        serialize = FALSE,
        file = TRUE
      )
      if (!identical(actual_sha256, expected_sha256)) {
        stop("Downloaded ONNX Runtime archive failed SHA-256 verification")
      }

      # Extract
      if (!quiet) {
        message("Extracting...")
      }

      if (platform == "Windows") {
        utils::unzip(ort_file, exdir = temp_dir, quiet = TRUE)
      } else {
        utils::untar(ort_file, exdir = temp_dir)
      }

      # Find the extracted directory
      extracted_dirs <- list.dirs(
        temp_dir,
        full.names = FALSE,
        recursive = FALSE
      )
      extracted_dir <- file.path(
        temp_dir,
        extracted_dirs[grepl("onnxruntime", extracted_dirs)]
      )

      if (length(extracted_dir) == 0 || !dir.exists(extracted_dir)) {
        # Try to find the extracted files directly
        extracted_dir <- temp_dir
      }

      # Determine library path
      lib_dir <- file.path(destdir, "lib")

      # Create directory if needed
      if (!dir.exists(lib_dir)) {
        dir.create(lib_dir, showWarnings = FALSE, recursive = TRUE)
      }

      # Copy library files
      if (!quiet) {
        message(sprintf("Installing to %s...", lib_dir))
      }

      # Helper to find and copy library file
      lib_filename <- switch(
        platform,
        "Linux" = "libonnxruntime.so",
        "Darwin" = "libonnxruntime.dylib",
        "Windows" = "onnxruntime.dll"
      )

      # Search for library file recursively
      found_lib <- list.files(
        extracted_dir,
        pattern = paste0("^", lib_filename, "$"),
        recursive = TRUE,
        full.names = TRUE
      )

      if (length(found_lib) > 0) {
        # Use the first match (usually the one in lib/ or root)
        copied <- file.copy(
          found_lib[1],
          file.path(lib_dir, lib_filename),
          overwrite = TRUE
        )
        if (!copied) {
          stop(
            "Failed to copy the ONNX Runtime library into destdir."
          )
        }

        # Also try to copy other contents of lib/ if it exists
        lib_src_dir <- file.path(extracted_dir, "lib")
        if (dir.exists(lib_src_dir)) {
          files_to_copy <- list.files(lib_src_dir, full.names = TRUE)
          # Exclude the one we just copied if it's the same
          files_to_copy <- files_to_copy[
            normalizePath(files_to_copy) != normalizePath(found_lib[1])
          ]
          if (length(files_to_copy) > 0) {
            file.copy(files_to_copy, lib_dir, overwrite = TRUE)
          }
        }
      } else {
        stop("Could not find ", lib_filename, " in extracted archive")
      }

      # Clean up
      unlink(temp_dir, recursive = TRUE)

      # Verify installation
      lib_file <- file.path(lib_dir, lib_filename)
      if (!file.exists(lib_file)) {
        stop("Installation verification failed: library file not found")
      }

      Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_file))
      setup_onnx_runtime()

      if (!quiet) {
        message(sprintf("ONNX Runtime installed successfully!"))
        message(sprintf("Library: %s", lib_file))
      }

      # Return success
      invisible(TRUE)
    },
    error = function(e) {
      unlink(temp_dir, recursive = TRUE)
      stop(sprintf("Failed to install ONNX Runtime: %s", e$message))
    }
  )
}

.onnx_runtime_sha256 <- function(version, archive) {
  checksums <- c(
    "1.28.0/onnxruntime-linux-aarch64-1.28.0.tgz" = "e15ff8b5d85afe6c144d97c6fd432254bf76a219daaf17658087d6ecb3e8f0bb",
    "1.28.0/onnxruntime-linux-x64-1.28.0.tgz" = "a3e1b79d7bb1bf09696ce675f49e4064e6c81f6202b8225624fff0e93f8d6407",
    "1.28.0/onnxruntime-osx-arm64-1.28.0.tgz" = "1268b359718099bde2cedb55787f182a130067bc4f31e8c88478c445b850d3d8",
    "1.28.0/onnxruntime-win-arm64-1.28.0.zip" = "cbe4547463ece092b505c3581376ed5896d22b5429f39d5e645e425ecdd369ad",
    "1.28.0/onnxruntime-win-x64-1.28.0.zip" = "abef733dacbe2f571547a7150b479b5cb9cc0df22f96c24983a42cadb1b4f8bc",
    "1.29.0/onnxruntime-linux-aarch64-1.29.0.tgz" = "e1799098ebc054b370f6176a450f158720f297818c613e5dc99b92e2ec82346f",
    "1.29.0/onnxruntime-linux-x64-1.29.0.tgz" = "c3fddc4f139a045b0c4902c57410f0694f1c2fdf9b6939fbe38b1aeae7cd14ba",
    "1.29.0/onnxruntime-osx-arm64-1.29.0.tgz" = "d0706fc34f315d8c88639d0a8c81f2e09e815f282cabed3493c06a054352cf92",
    "1.29.0/onnxruntime-win-arm64-1.29.0.zip" = "a094a49c3ced0f9fca554647cc7566ae99d93a63a8ce6bf47975561c2de7608e",
    "1.29.0/onnxruntime-win-x64-1.29.0.zip" = "c9b4b7086b529ad814f428c1bad028e20a25d7dc0699836775faace4ab5b78b2"
  )
  checksum <- unname(checksums[paste(version, archive, sep = "/")])
  if (length(checksum) != 1L || is.na(checksum)) {
    stop(
      "No verified SHA-256 checksum is available for this ONNX Runtime archive."
    )
  }
  checksum
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
  configured_path <- Sys.getenv("ORT_DYLIB_PATH", unset = "")
  if (nzchar(configured_path) && file.exists(configured_path)) {
    return(configured_path)
  }
  platform <- Sys.info()[["sysname"]]
  pkg_path <- system.file(package = "churon")

  lib_name <- switch(
    platform,
    "Linux" = "libonnxruntime.so",
    "Darwin" = "libonnxruntime.dylib",
    "Windows" = "onnxruntime.dll",
    stop(sprintf("Unsupported platform: %s", platform))
  )

  file.path(pkg_path, "onnxruntime", "lib", lib_name)
}
