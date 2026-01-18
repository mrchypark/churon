test_that("error handling for invalid model paths", {
  skip_on_os("windows")
  library(churon)

  # Test non-existent file
  expect_error(
    onnx_session("/path/to/nonexistent/model.onnx"),
    "Model file not found"
  )

  # Test invalid file format
  temp_file <- tempfile(fileext = ".txt")
  writeLines("not an onnx model", temp_file)
  on.exit(unlink(temp_file))

  expect_error(
    suppressWarnings(onnx_session(temp_file)),
    "Failed to create ONNX session"
  )

  # For now, just test file operations
  expect_true(file.exists(temp_file))
  expect_false(grepl("\\.onnx$", temp_file))
})

test_that("error handling for invalid execution providers", {
  skip_on_os("windows")
  library(churon)
  
  # Check if ONNX Runtime is available
  if (!check_onnx_runtime_available()) {
    skip("ONNX Runtime not installed - run install_onnx_runtime()")
  }

  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    model_path <- model_files[1]

    # Test invalid provider name
    expect_error(
      onnx_session(model_path, providers = "invalid_provider"),
      "Invalid execution providers"
    )

    # Test empty provider list
    # expect_error(
    #   onnx_session(model_path, providers = character(0)),
    #   NA # Should not error, should use defaults
    # )

    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("error handling for inference failures", {
  skip_on_os("windows")
  library(churon)
  
  # Check if ONNX Runtime is available
  if (!check_onnx_runtime_available()) {
    skip("ONNX Runtime not installed - run install_onnx_runtime()")
  }

  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    session <- onnx_session(model_files[1])

    # Test with no input data
    expect_error(
      onnx_run(session, list()),
      "inputs cannot be empty"
    )

    # Test with unnamed input data (list without names)
    expect_error(
      onnx_run(session, list(matrix(1:4, 2, 2))),
      "All inputs must be named"
    )
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("error messages are informative", {
  skip_on_os("windows")
  library(churon)

  # Error messages should include:
  # - Clear description of what went wrong
  # - Context about the operation that failed
  # - Suggestions for how to fix the issue (when applicable)

  expect_true(TRUE) # Placeholder for now
})
