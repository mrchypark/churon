test_that("session creation with valid model", {
  skip_if_not_installed("churon")
  library(churon)

  models <- onnx_example_models()

  if (length(models) > 0) {
    # Test session creation with example model
    session <- onnx_example_session("mnist")
    expect_s3_class(session, "RSession")
    expect_true(!is.null(session))
  } else {
    skip("No example models available")
  }
})

test_that("session creation with execution providers", {
  skip_if_not_installed("churon")
  library(churon)

  models <- onnx_example_models()

  if (length(models) > 0) {
    # Test CPU provider
    session_cpu <- onnx_session(models[1], providers = "cpu")
    expect_s3_class(session_cpu, "RSession")

    # Test default providers (no explicit provider)
    session_default <- onnx_session(models[1])
    expect_s3_class(session_default, "RSession")
  } else {
    skip("No example models available")
  }
})

test_that("session information retrieval", {
  skip_if_not_installed("churon")
  library(churon)

  models <- onnx_example_models()

  if (length(models) > 0) {
    session <- onnx_session(models[1])

    # Test input information
    input_info <- onnx_input_info(session)
    expect_type(input_info, "list")
    expect_true(length(input_info) > 0)

    # Test output information
    output_info <- onnx_output_info(session)
    expect_type(output_info, "list")
    expect_true(length(output_info) > 0)

    # Test provider information
    providers <- onnx_providers(session)
    expect_type(providers, "character")
    expect_true(length(providers) > 0)

    # Test model path retrieval
    model_path <- onnx_model_path(session)
    expect_type(model_path, "character")
    expect_true(nchar(model_path) > 0)
  } else {
    skip("No example models available")
  }
})
