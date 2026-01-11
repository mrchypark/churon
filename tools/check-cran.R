# CRAN Check Script for churon
# This script mimics the CRAN submission checks, including Rust vendoring.

check_cran <- function() {
  # Ensure we are in the package root
  if (!file.exists("DESCRIPTION")) {
    stop("Please run this script from the package root directory.")
  }

  message("=== Starting CRAN Check Process ===")

  # 1. Vendor Rust Dependencies
  # CRAN does not allow internet access during build, so we must bundle crates.
  message("\n[1/4] Vendoring Rust dependencies...")
  if (requireNamespace("rextendr", quietly = TRUE)) {
    # This downloads crates to src/rust/vendor and updates Cargo.toml
    rextendr::vendor_pkgs()
    message("Vendoring complete.")
  } else {
    stop("rextendr package is required. Run tools/setup-dev.R")
  }

  # 2. Build Source Package
  message("\n[2/4] Building source package...")
  # Clean previous builds
  previous_tarballs <- list.files(pattern = "\\.tar\\.gz$")
  if (length(previous_tarballs) > 0) {
    file.remove(previous_tarballs)
  }
  
  # Build
  pkg_path <- devtools::build(quiet = TRUE)
  message(sprintf("Package built at: %s", pkg_path))

  # 3. Run R CMD check --as-cran
  message("\n[3/4] Running R CMD check --as-cran...")
  message("This may take a while...")
  
  # We need to make sure ONNX Runtime is available for the check
  # The check runs in a separate process, so environment variables must be passed if needed
  
  check_results <- rcmdcheck::rcmdcheck(
    path = pkg_path,
    args = c("--as-cran", "--no-manual"),
    error_on = "never" # We want to see the full report even on error
  )

  # 4. Report Results
  message("\n=== Check Results ===")
  print(check_results)

  # 5. Cleanup (Optional - commented out for debugging)
  # message("\n[5/5] Cleaning up vendored files...")
  # system("rm -rf src/rust/vendor")
  # system("git checkout src/rust/Cargo.toml") 
  
  if (length(check_results$errors) > 0) {
    message("\n❌ Check FAILED with errors.")
    return(invisible(FALSE))
  } else if (length(check_results$warnings) > 0) {
    message("\n⚠️ Check PASSED with warnings (fix before CRAN submission).")
    return(invisible(TRUE))
  } else {
    message("\n✅ Check PASSED successfully!")
    return(invisible(TRUE))
  }
}

if (!interactive()) {
  check_cran()
}
