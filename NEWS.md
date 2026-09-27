# churon 0.1.13

* Fix source installation when Rust is installed in `~/.cargo/bin` but is not
  on `PATH`, as on the CRAN macOS builders. Rust version requirements continue
  to be checked by `configure`.
