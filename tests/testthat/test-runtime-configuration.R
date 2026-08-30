test_that("a valid configured ONNX Runtime path is preserved", {
  runtime <- tempfile("onnxruntime")
  file.create(runtime)
  previous <- Sys.getenv("ORT_DYLIB_PATH", unset = NA_character_)
  loader_variable <- switch(
    Sys.info()[["sysname"]],
    Darwin = "DYLD_LIBRARY_PATH",
    Linux = "LD_LIBRARY_PATH",
    Windows = "PATH"
  )
  previous_loader_path <- Sys.getenv(loader_variable, unset = NA_character_)
  on.exit(
    {
      if (is.na(previous)) {
        Sys.unsetenv("ORT_DYLIB_PATH")
      } else {
        Sys.setenv(ORT_DYLIB_PATH = previous)
      }
      if (is.na(previous_loader_path)) {
        Sys.unsetenv(loader_variable)
      } else {
        do.call(
          Sys.setenv,
          setNames(list(previous_loader_path), loader_variable)
        )
      }
      unlink(runtime)
    },
    add = TRUE
  )

  Sys.setenv(ORT_DYLIB_PATH = runtime)
  expect_true(churon:::setup_onnx_runtime())
  expect_equal(Sys.getenv("ORT_DYLIB_PATH"), normalizePath(runtime))
})

test_that("a missing configured ONNX Runtime path falls back gracefully", {
  previous <- Sys.getenv("ORT_DYLIB_PATH", unset = NA_character_)
  on.exit(
    {
      if (is.na(previous)) {
        Sys.unsetenv("ORT_DYLIB_PATH")
      } else {
        Sys.setenv(ORT_DYLIB_PATH = previous)
      }
    },
    add = TRUE
  )

  Sys.setenv(ORT_DYLIB_PATH = tempfile("missing-onnxruntime"))
  available <- file.exists(churon:::onnx_runtime_lib_path())
  expect_identical(churon:::setup_onnx_runtime(), available)
  if (available) {
    expect_equal(
      Sys.getenv("ORT_DYLIB_PATH"),
      normalizePath(churon:::onnx_runtime_lib_path())
    )
  } else {
    expect_false(nzchar(Sys.getenv("ORT_DYLIB_PATH")))
  }
})

test_that("runtime installer enforces verified compatible versions", {
  expect_error(
    install_onnx_runtime(NA_character_, quiet = TRUE),
    "version must be one non-missing character string"
  )
  expect_error(
    install_onnx_runtime("1.27.0", quiet = TRUE),
    "supports ONNX Runtime versions 1.28.0 and 1.29.0"
  )
  expect_identical(
    churon:::.onnx_runtime_sha256(
      "1.29.0",
      "onnxruntime-linux-x64-1.29.0.tgz"
    ),
    "c3fddc4f139a045b0c4902c57410f0694f1c2fdf9b6939fbe38b1aeae7cd14ba"
  )
})
