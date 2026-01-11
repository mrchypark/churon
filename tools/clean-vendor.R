# Cleanup Vendored Files
# Run this to remove vendor/ directory and restore Cargo.toml to original state

clean_vendor <- function() {
  message("Cleaning up vendored files...")
  
  if (dir.exists("src/rust/vendor")) {
    unlink("src/rust/vendor", recursive = TRUE)
    message("- Removed src/rust/vendor/")
  }
  
  if (file.exists("src/rust/vendor-config.toml")) {
    unlink("src/rust/vendor-config.toml")
    message("- Removed src/rust/vendor-config.toml")
  }
  
  # Note: rextendr::vendor_pkgs() modifies Cargo.toml. 
  # Ideally we should have a backup or rely on git to restore it.
  message("Note: src/rust/Cargo.toml may have been modified.")
  message("Run 'git checkout src/rust/Cargo.toml' to discard changes if desired.")
}

if (!interactive()) {
  clean_vendor()
}
