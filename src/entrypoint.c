// We need to forward routine registration from C to Rust
// to avoid the linker removing the static library.

void R_init_churon_extendr(void *dll);

// We need to forward routine registration from C to Rust
// to avoid the linker removing the static library.

void R_init_churon_extendr(void *dll);

void R_init_churon(void *dll) {
    R_init_churon_extendr(dll);
}

// Check for abort symbol to prevent R CMD check warnings
// This overrides the standard library abort to use R's error handling
// which prevents the R session from crashing if Rust panics.
// Based on patterns used in other CRAN packages (e.g. gifski)
#include <Rinternals.h>
#include <stdlib.h>

#ifndef _WIN32
__attribute__((visibility("hidden"))) void abort(void) {
    Rf_error("Rust panic: Aborting churon execution");
    __builtin_unreachable();
}
#endif
