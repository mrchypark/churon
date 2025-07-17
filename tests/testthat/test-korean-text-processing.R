test_that("korean spacing models are available", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  kospacing_models <- models[grepl("kospacing", names(models), ignore.case = TRUE)]
  
  if (length(kospacing_models) > 0) {
    # Test that kospacing models exist
    for (model_path in kospacing_models) {
      expect_true(file.exists(model_path))
      expect_match(basename(model_path), "kospacing", ignore.case = TRUE)
    }
    
    # Test loading kospacing model
    expect_no_error({
      session <- onnx_session(kospacing_models[1])
      expect_true(!is.null(session))
    })
  } else {
    skip("No Korean spacing models found for testing")
  }
})

test_that("korean text input validation", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  kospacing_models <- models[grepl("kospacing", names(models), ignore.case = TRUE)]
  
  if (length(kospacing_models) > 0) {
    session <- onnx_session(kospacing_models[1])
    input_info <- onnx_input_info(session)
    
    # Validate that we have input information
    expect_true(length(input_info) > 0)
    
    # Check input tensor properties
    for (i in seq_along(input_info)) {
      tensor_info <- input_info[[i]]
      expect_true(!is.null(tensor_info$name))
      expect_true(!is.null(tensor_info$shape))
      expect_true(!is.null(tensor_info$data_type))
      expect_true(nchar(tensor_info$name) > 0)
    }
  } else {
    skip("No Korean spacing models found for input validation testing")
  }
})

test_that("model metadata is accessible", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    session <- onnx_session(models[1])
    
    # Test input information structure
    input_info <- onnx_input_info(session)
    if (length(input_info) > 0) {
      first_input <- input_info[[1]]
      expect_true(is.list(first_input) || inherits(first_input, "TensorInfo"))
    }
    
    # Test output information structure
    output_info <- onnx_output_info(session)
    if (length(output_info) > 0) {
      first_output <- output_info[[1]]
      expect_true(is.list(first_output) || inherits(first_output, "TensorInfo"))
    }
    
    # Test provider information
    providers <- onnx_providers(session)
    expect_true(is.character(providers))
    expect_true(length(providers) > 0)
    
    # CPU should always be available as fallback
    expect_true("CPU" %in% providers)
  } else {
    skip("No models available for metadata testing")
  }
})

test_that("multiple models can be loaded simultaneously", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) >= 2) {
    # Load multiple sessions
    session1 <- onnx_session(models[1])
    session2 <- onnx_session(models[2])
    
    # Both sessions should be valid
    expect_true(!is.null(session1))
    expect_true(!is.null(session2))
    
    # They should have different model paths
    path1 <- onnx_model_path(session1)
    path2 <- onnx_model_path(session2)
    expect_false(identical(path1, path2))
    
    # Both should provide valid information
    expect_true(length(onnx_input_info(session1)) > 0)
    expect_true(length(onnx_input_info(session2)) > 0)
    expect_true(length(onnx_output_info(session1)) > 0)
    expect_true(length(onnx_output_info(session2)) > 0)
  } else {
    skip("Need at least 2 models for simultaneous loading test")
  }
})

test_that("execution provider selection works", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    
    # Test CPU provider explicitly
    expect_no_error({
      session_cpu <- onnx_session(model_path, providers = "cpu")
      providers <- onnx_providers(session_cpu)
      expect_true("CPU" %in% providers)
    })
    
    # Test multiple providers (should fallback to available ones)
    expect_no_error({
      session_multi <- onnx_session(model_path, providers = c("cuda", "cpu"))
      providers <- onnx_providers(session_multi)
      expect_true(length(providers) > 0)
      expect_true("CPU" %in% providers) # CPU should always be available
    })
    
    # Test invalid provider
    expect_error(
      onnx_session(model_path, providers = "invalid_provider"),
      "Invalid execution providers"
    )
  } else {
    skip("No models available for execution provider testing")
  }
})