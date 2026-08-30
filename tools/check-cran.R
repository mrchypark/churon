# CRAN Check Script for churon
# This script checks the committed source package without network access.

check_cran <- function() {
  # Ensure we are in the package root
  if (!file.exists("DESCRIPTION")) {
    stop("Please run this script from the package root directory.")
  }

  message("=== Starting CRAN Check Process ===")

  # CRAN builds from the committed vendor archive without network access.
  if (!file.exists("src/rust/vendor.tar.xz")) {
    stop("src/rust/vendor.tar.xz is required for an offline build.")
  }

  message("\n[1/2] Building source package...")
  pkg_path <- devtools::build(quiet = TRUE)
  message(sprintf("Package built at: %s", pkg_path))

  message("\n[2/2] Running R CMD check --as-cran offline...")
  message("This may take a while...")

  check_results <- rcmdcheck::rcmdcheck(
    path = pkg_path,
    args = c("--as-cran", "--no-manual"),
    env = c(
      http_proxy = "http://127.0.0.1:9",
      https_proxy = "http://127.0.0.1:9",
      "_R_CHECK_CRAN_INCOMING_REMOTE_" = "false"
    ),
    error_on = "warning"
  )

  # 4. Report Results
  message("\n=== Check Results ===")
  print(check_results)

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
