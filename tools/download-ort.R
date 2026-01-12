cat("Hello from download-ort.R\n")

# ONNX Runtime Download and Setup Script for churon package
# This script downloads and configures ONNX Runtime for the current platform

cat("Starting download-ort.R script...\n")

download_onnx_runtime <- function() {
  # ONNX Runtime version - must be >= 1.23.2 for ort v2.x
  ort_version <- "1.23.2"
  
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

  # Set up library name (base name, not versioned)
  lib_base_name <- switch(platform_name,
    "linux" = "libonnxruntime.so",
    "osx" = "libonnxruntime.dylib", 
    "win" = "onnxruntime.dll"
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
  tools_dir <- "tools"
  if (!dir.exists(tools_dir)) {
    dir.create(tools_dir, recursive = TRUE)
  }
  
  # Set up paths
  expected_ort_dir <- file.path(tools_dir, paste0("onnxruntime-", platform_name, "-", arch_name, "-", ort_version))
  archive_path <- file.path(tools_dir, archive_name)
  
  # Check if ONNX Runtime is already downloaded and valid
  need_download <- TRUE
  if (dir.exists(expected_ort_dir)) {
    cat("Checking existing ONNX Runtime at:", expected_ort_dir, "\n")
    
    # Search for library in the directory
    lib_pattern <- switch(platform_name,
      "win" = "onnxruntime.*\\.dll$",
      "osx" = "libonnxruntime.*\\.dylib$",
      "linux" = "libonnxruntime\\.so"
    )
    
    found_libs <- list.files(expected_ort_dir, pattern = lib_pattern, recursive = TRUE, full.names = TRUE)
    
    if (length(found_libs) > 0) {
      cat("Found existing library:", found_libs[1], "\n")
      need_download <- FALSE
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
      # First, extract to a temporary location to find the actual directory name
      temp_extract_dir <- file.path(tools_dir, "temp_extract")
      if (dir.exists(temp_extract_dir)) {
        unlink(temp_extract_dir, recursive = TRUE)
      }
      dir.create(temp_extract_dir, recursive = TRUE)
      
      if (platform_name == "win") {
        unzip(archive_path, exdir = temp_extract_dir)
      } else {
        untar(archive_path, exdir = temp_extract_dir)
      }
      
      # Find the extracted directory (it should be onnxruntime-*)
      extracted_dirs <- list.dirs(temp_extract_dir, full.names = TRUE, recursive = FALSE)
      extracted_dir <- extracted_dirs[grepl("onnxruntime", extracted_dirs)]
      
      if (length(extracted_dir) == 0) {
        stop("Could not find ONNX Runtime directory in extracted archive")
      }
      
      if (length(extracted_dir) > 1) {
        cat("Multiple ONNX Runtime directories found, using first one:", extracted_dir[1], "\n")
        extracted_dir <- extracted_dir[1]
      }
      
      cat("Extracted directory:", extracted_dir, "\n")
      
      # Move extracted contents to expected location
      if (dir.exists(expected_ort_dir)) {
        unlink(expected_ort_dir, recursive = TRUE)
      }
      file.rename(extracted_dir, expected_ort_dir)
      
      # Clean up
      unlink(temp_extract_dir, recursive = TRUE)
      unlink(archive_path)
      cat("Extraction completed successfully\n")
    }, error = function(e) {
      stop("Failed to extract ONNX Runtime: ", e$message)
    })
  }
  
  # Now find the library in the extracted directory
  cat("Searching for library in:", expected_ort_dir, "\n")
  
  # Search patterns for finding library files
  lib_pattern <- switch(platform_name,
    "win" = "onnxruntime.*\\.dll$",
    "osx" = "libonnxruntime.*\\.dylib$",
    "linux" = "libonnxruntime\\.so"
  )
  
  # Find all matching libraries
  found_libs <- list.files(expected_ort_dir, pattern = lib_pattern, recursive = TRUE, full.names = TRUE)
  cat("Found libraries:", found_libs, "\n")
  
  if (length(found_libs) == 0) {
    stop("No ONNX Runtime library found in ", expected_ort_dir)
  }
  
  # Use the first match (prefer non-versioned if available)
  lib_path <- found_libs[1]
  cat("Using library:", lib_path, "\n")
  
  # Create lib directory if it doesn't exist
  lib_dir <- file.path(expected_ort_dir, "lib")
  if (!dir.exists(lib_dir)) {
    dir.create(lib_dir, recursive = TRUE)
  }
  
  # Copy library to lib/ directory with standard name
  dest_lib_path <- file.path(lib_dir, lib_base_name)
  if (normalizePath(lib_path) != normalizePath(dest_lib_path)) {
    file.copy(lib_path, dest_lib_path, overwrite = TRUE)
    cat("Copied library to:", dest_lib_path, "\n")
    lib_path <- dest_lib_path
  }
  
  # Also copy any other library files (versioned ones)
  for (f in found_libs) {
    if (normalizePath(f) != normalizePath(lib_path)) {
      file.copy(f, file.path(lib_dir, basename(f)), overwrite = TRUE)
    }
  }
  
  # Find include directory
  include_dir <- file.path(expected_ort_dir, "include")
  if (!dir.exists(include_dir)) {
    # Search for include directory
    found_includes <- list.dirs(expected_ort_dir, full.names = TRUE, recursive = FALSE)
    include_dir <- found_includes[grepl("include", found_includes)]
    if (length(include_dir) == 0) {
      cat("Warning: Include directory not found\n")
      include_dir <- file.path(expected_ort_dir, "include")
    }
  }
  cat("Include directory:", include_dir, "\n")
  
  # Create include directory if it doesn't exist
  if (!dir.exists(include_dir)) {
    dir.create(include_dir, recursive = TRUE)
  }
  
  # Verify library exists
  if (!file.exists(lib_path)) {
    stop("ONNX Runtime library not found at: ", lib_path)
  }
  
  cat("ONNX Runtime library found at:", lib_path, "\n")
  
  # Set environment variables
  Sys.setenv(ORT_DYLIB_PATH = normalizePath(lib_path))
  Sys.setenv(ORT_INCLUDE_PATH = normalizePath(include_dir))
  Sys.setenv(ORT_LIB_PATH = normalizePath(lib_dir))
  
  cat("Environment variables set:\n")
  cat("  ORT_DYLIB_PATH =", Sys.getenv("ORT_DYLIB_PATH"), "\n")
  cat("  ORT_INCLUDE_PATH =", Sys.getenv("ORT_INCLUDE_PATH"), "\n")
  cat("  ORT_LIB_PATH =", Sys.getenv("ORT_LIB_PATH"), "\n")
  
  # Copy to inst directory for package installation
  cat("Copying ONNX Runtime to inst directory...\n")
  inst_lib_dir <- file.path("inst", "onnxruntime", "lib")
  inst_inc_dir <- file.path("inst", "onnxruntime", "include")
  
  if (!dir.exists(inst_lib_dir)) dir.create(inst_lib_dir, recursive = TRUE)
  if (!dir.exists(inst_inc_dir)) dir.create(inst_inc_dir, recursive = TRUE)
  
  # Copy library files
  if (dir.exists(lib_dir)) {
    lib_files <- list.files(lib_dir, full.names = TRUE)
    if (length(lib_files) > 0) {
      file.copy(lib_files, inst_lib_dir, recursive = TRUE)
      cat("Copied", length(lib_files), "library files to", inst_lib_dir, "\n")
    }
  }
  
  # Copy include files
  if (dir.exists(include_dir)) {
    inc_files <- list.files(include_dir, full.names = TRUE, recursive = TRUE)
    if (length(inc_files) > 0) {
      file.copy(inc_files, inst_inc_dir, recursive = TRUE)
      cat("Copied", length(inc_files), "include files to", inst_inc_dir, "\n")
    }
  }
  
  # Write src/ort_config.env for Makevars
  cat("Writing src/ort_config.env...\n")
  config_content <- c(
    paste0('export ORT_DYLIB_PATH="', normalizePath(lib_path), '"'),
    paste0('export ORT_INCLUDE_PATH="', normalizePath(include_dir), '"'),
    paste0('export ORT_LIB_PATH="', normalizePath(lib_dir), '"')
  )
  writeLines(config_content, "src/ort_config.env")
  
  return(list(
    lib_path = lib_path,
    include_path = include_dir,
    ort_dir = expected_ort_dir
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
