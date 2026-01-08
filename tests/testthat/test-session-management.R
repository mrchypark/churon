test_that("session creation with valid model", {
  skip_if_not_installed("churon")
  library(churon)

  # Get example model path
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    model_path <- model_files[1]

    # TODO: Implement when onnx_session function is available
    # session <- onnx_session(model_path)
    # expect_s3_class(session, "onnx_session")
    # expect_true(!is.null(session))

    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("session creation with execution providers", {
  skip_if_not_installed("churon")
  library(churon)

  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    model_path <- model_files[1]

    # TODO: Implement when onnx_session function is available
    # Test CPU provider
    # session_cpu <- onnx_session(model_path, providers = "cpu")
    # expect_s3_class(session_cpu, "onnx_session")

    # Test multiple providers with fallback
    # session_multi <- onnx_session(model_path, providers = c("cuda", "cpu"))
    # expect_s3_class(session_multi, "onnx_session")

    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("session information retrieval", {
  skip_if_not_installed("churon")
  library(churon)

  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)

  if (length(model_files) > 0) {
    model_path <- model_files[1]

    # TODO: Implement when session functions are available
    # session <- onnx_session(model_path)

    # Test input information
    # input_info <- onnx_input_info(session)
    # expect_type(input_info, "list")
    # expect_true(length(input_info) > 0)

    # Test output information
    # output_info <- onnx_output_info(session)
    # expect_type(output_info, "list")
    # expect_true(length(output_info) > 0)

    # Test provider information
    # providers <- onnx_providers(session)
    # expect_type(providers, "character")
    # expect_true(length(providers) > 0)

    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})
