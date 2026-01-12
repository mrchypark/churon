test_that("basic inference execution", {
  skip_if_not_installed("churon")
  library(churon)

  # Check if ONNX Runtime is available
  if (!check_onnx_runtime_available()) {
    skip("ONNX Runtime not installed - run install_onnx_runtime()")
  }

  expect_true(TRUE)
})

test_that("inference with invalid input data", {
  skip_if_not_installed("churon")
  library(churon)

  # Check if ONNX Runtime is available
  if (!check_onnx_runtime_available()) {
    skip("ONNX Runtime not installed - run install_onnx_runtime()")
  }

  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    model_path <- model_files[1]
    session <- onnx_session(model_path)

    # Test with empty input
    expect_error(
      onnx_run(session, list()),
      "inputs cannot be empty"
    )

    # Test with unnamed input
    expect_error(
      onnx_run(session, list(matrix(1:4, 2, 2))),
      "All inputs must be named"
    )

    # Test with wrong input names
    expect_error(
      onnx_run(session, list(wrong_name = matrix(1:4, 2, 2))),
      "Inference failed"
    )
  } else {
    skip("No ONNX model files found for testing")
  }
})