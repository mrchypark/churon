cat("Hello from download-ort.R\n")

# ONNX Runtime Download and Setup Script for churon package
# This script downloads and configures ONNX Runtime for the current platform

cat("Starting download-ort.R script...\n")

download_onnx_runtime <- function() {
  # ONNX Runtime version - must be >= 1.23.0 for ort v2.x
  ort_version <- "1.23.0"
  
  # Detect platform and architecture
  platform <- Sys.info()["sysname"]
  arch <- Sys.info()["machine"]
  
  # Normalize platform names
  platform_name <- switch(platform,
    "Linux" = "linux",
    "Darwin" = "osx", 
    "Windows" = "win",
    stop("Unsupported platform: ", platform)
  )
  
  # Normalize architecture names
  if (arch == "wasm32" || platform == "Emscripten") {
    cat("WASM/Emscripten detected. Skipping ONNX Runtime download (handled by web runtime).\n")
    return(NULL)
  }

  arch_name <- switch(arch,
    "x86_64" = "x64",
    "x86-64" = "x64",
    "amd64" = "x64",
    "arm64" = "arm64",
    "aarch64" = "arm64",
    stop("Unsupported architecture: ", arch)
  )
  
  cat("Detected platform:", platform_name, "-", arch_name, "\n")
  
  # Construct download URL and filename
  if (platform_name == "osx" && arch_name == "arm64") {
    archive_name <- paste0("onnxruntime-osx-arm64-", ort_version, ".tgz")
  } else if (platform_name == "osx") {
    archive_name <- paste0("onnxruntime-osx-x86_64-", ort_version, ".tgz")
  } else if (platform_name == "win") {
    if (arch_name == "arm64") {
      archive_name <- paste0("onnxruntime-win-arm64-", ort_version, ".zip")
    } else {
      archive_name <- paste0("onnxruntime-win-x64-", ort_version, ".zip")
    }
  } else {
    archive_name <- paste0("onnxruntime-linux-", arch_name, "-", ort_version, ".tgz")
  }
  
  download_url <- paste0("https://github.com/microsoft/onnxruntime/releases/download/v", 
                        ort_version, "/", archive_name)
  
  # Create tools directory if it doesn't exist
  if (!dir.exists("tools")) {
    dir.create("tools", recursive = TRUE)
  }
  
  # Set up paths
  ort_dir <- file.path("tools", paste0("onnxruntime-", platform_name, "-", arch_name, "-", ort_version))
  archive_path <- file.path("tools", archive_name)
  
  # Check if ONNX Runtime is already downloaded and valid
  need_download <- TRUE
  if (dir.exists(ort_dir)) {
    # Check if content exists (basic validation)
    if (length(list.files(ort_dir, recursive = TRUE)) > 5) {
      cat("ONNX Runtime already exists at:", ort_dir, "\n")
      need_download <- FALSE
    } else {
      cat("ONNX Runtime directory exists but appears empty or corrupt. Removing and re-downloading.\n")
      unlink(ort_dir, recursive = TRUE)
    }
  }
  
  if (need_download) {
    cat("Downloading ONNX Runtime", ort_version, "for", platform_name, "-", arch_name, "\n")
    cat("URL:", download_url, "\n")
    
    # Download with error handling
    tryCatch({
      if (getRversion() < "3.3.0") setInternet2()
      download.file(download_url, destfile = archive_path, mode = "wb", quiet = FALSE)
      cat("Download completed successfully\n")
    }, error = function(e) {
      stop("Failed to download ONNX Runtime: ", e$message)
    })
    
    # Extract archive
    cat("Extracting ONNX Runtime...\n")
    tryCatch({
      if (platform_name == "win") {
        unzip(archive_path, exdir = "tools")
      } else {
        untar(archive_path, exdir = "tools")
      }
      
      # Clean up archive
      unlink(archive_path)
      cat("Extraction completed successfully\n")
    }, error = function(e) {
      stop("Failed to extract ONNX Runtime: ", e$message)
    })
  }
  
  # Set up library path
  lib_name <- switch(platform_name,
    "linux" = "libonnxruntime.so",
    "osx" = "libonnxruntime.dylib", 
    "win" = "onnxruntime.dll"
  )
  
  lib_path <- file.path(ort_dir, "lib", lib_name)
  
  # Check if library exists in standard path, if not search for it
  # This handles variations in archive structure across platforms and versions
  if (!file.exists(lib_path)) {
    cat("Library not found at", lib_path, "- searching...\n")
    
    potential_paths <- c(
      file.path(ort_dir, lib_name),
      file.path(ort_dir, "bin", lib_name)
    )
    
    # Also search recursively as a fallback
    # Relaxed pattern to match versioned files (e.g. libonnxruntime.1.23.0.dylib)
    search_pattern <- switch(platform_name,
      "win" = "onnxruntime.*\\.dll$",
      "osx" = "libonnxruntime.*\\.dylib",
      "linux" = "libonnxruntime.*\\.so"
    )
    found_libs <- list.files(ort_dir, pattern = search_pattern, recursive = TRUE, full.names = TRUE)
    if (length(found_libs) > 0) {
      potential_paths <- c(potential_paths, found_libs)
    }
    
    for (p in potential_paths) {
      if (file.exists(p)) {
        cat("Found library at:", p, "\n")
        # Copy to lib folder to maintain consistent structure
        if (!dir.exists(file.path(ort_dir, "lib"))) {
          dir.create(file.path(ort_dir, "lib"), recursive = TRUE)
        }
        # Only copy if source and dest are different
        if (normalizePath(p) != normalizePath(lib_path, mustWork = FALSE)) {
             file.copy(p, lib_path)
        }
        break
      }
    }
  }

  include_path <- file.path(ort_dir, "include")
  
  # Verify library exists
  if (!file.exists(lib_path)) {
    stop("ONNX Runtime library not found at expected path: ", lib_path)
  }
  
  cat("ONNX Runtime library found at:", lib_path, "\n")
  
  # Set environment variables
  Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_path))
  Sys.setenv(ORT_INCLUDE_PATH = normalizePath(include_path))
  Sys.setenv(ORT_LIB_PATH = normalizePath(file.path(ort_dir, "lib")))
  
  cat("Environment variables set:\n")
  cat("  ORT_DYLIB_PATH =", Sys.getenv("ORT_DYLIB_PATH"), "\n")
  cat("  ORT_INCLUDE_PATH =", Sys.getenv("ORT_INCLUDE_PATH"), "\n")
  cat("  ORT_LIB_PATH =", Sys.getenv("ORT_LIB_PATH"), "\n")
  
  # Copy to inst directory for package installation
  # This ensures the library is included in the installed package
  cat("Copying ONNX Runtime to inst directory...\n")
  inst_lib_dir <- file.path("inst", "onnxruntime", "lib")
  inst_inc_dir <- file.path("inst", "onnxruntime", "include")
  
  if (!dir.exists(inst_lib_dir)) dir.create(inst_lib_dir, recursive = TRUE)
  if (!dir.exists(inst_inc_dir)) dir.create(inst_inc_dir, recursive = TRUE)
  
  # Copy files - use file.copy with recursive=TRUE for directories if needed
  # but here we copy contents of lib/ and include/
  file.copy(list.files(file.path(ort_dir, "lib"), full.names = TRUE), inst_lib_dir, recursive = TRUE)
  file.copy(list.files(file.path(ort_dir, "include"), full.names = TRUE), inst_inc_dir, recursive = TRUE)
  
  # Write src/ort_config.env for Makevars
  cat("Writing src/ort_config.env...\n")
  config_content <- c(
    paste0('export ORT_DYLIB_PATH="', normalizePath(lib_path), '"'),
    paste0('export ORT_INCLUDE_PATH="', normalizePath(include_path), '"'),
    paste0('export ORT_LIB_PATH="', normalizePath(file.path(ort_dir, "lib")), '"')
  )
  writeLines(config_content, "src/ort_config.env")
  
  return(list(
    lib_path = lib_path,
    include_path = include_path,
    ort_dir = ort_dir
  ))
}

# Function to check if ONNX Runtime is available
check_onnx_runtime <- function() {
  ort_path <- Sys.getenv("ORT_DYLIB_PATH")
  if (nchar(ort_path) == 0) {
    return(FALSE)
  }
  return(file.exists(ort_path))
}

# Main execution when script is sourced
if (!interactive()) {
  cat("Setting up ONNX Runtime for churon package...\n")
  result <- download_onnx_runtime()
  cat("ONNX Runtime setup completed successfully!\n")
}
