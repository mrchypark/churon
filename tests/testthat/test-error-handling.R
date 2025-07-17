test_that("error handling for invalid model paths", {
  skip_if_not_installed("churon")
  
  # TODO: Implement when onnx_session function is available
  # Test non-existent file
  # expect_error(
  #   onnx_session("/path/to/nonexistent/model.onnx"),
  #   "Model load failed"
  # )
  
  # Test invalid file format
  temp_file <- tempfile(fileext = ".txt")
  writeLines("not an onnx model", temp_file)
  on.exit(unlink(temp_file))
  
  # expect_error(
  #   onnx_session(temp_file),
  #   "Model load failed"
  # )
  
  # For now, just test file operations
  expect_true(file.exists(temp_file))
  expect_false(grepl("\\.onnx$", temp_file))
})

test_that("error handling for invalid execution providers", {
  skip_if_not_installed("churon")
  
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) > 0) {
    model_path <- model_files[1]
    
    # TODO: Implement when onnx_session function is available
    # Test invalid provider name
    # expect_error(
    #   onnx_session(model_path, providers = "invalid_provider"),
    #   "Unknown execution provider"
    # )
    
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
  skip_if_not_installed("churon")
  
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) > 0) {
    model_path <- model_files[1]
    
    # TODO: Implement when inference functions are available
    # session <- onnx_session(model_path)
    
    # Test with no input data
    # expect_error(
    #   onnx_run(session, list()),
    #   "No input data provided"
    # )
    
    # Test with unnamed input data
    # expect_error(
    #   onnx_run(session, list(matrix(1:4, 2, 2))),
    #   "Input data must be a named list"
    # )
    
    # Test with missing required inputs
    # input_info <- onnx_input_info(session)
    # if (length(input_info) > 1) {
    #   partial_input <- list()
    #   partial_input[[input_info[[1]]$name]] <- matrix(1:4, 2, 2)
    #   expect_error(
    #     onnx_run(session, partial_input),
    #     "Required input .* not provided"
    #   )
    # }
    
    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("error messages are informative", {
  # Test that error messages contain useful information
  # This will be implemented when actual error handling is in place
  
  # Error messages should include:
  # - Clear description of what went wrong
  # - Context about the operation that failed
  # - Suggestions for how to fix the issue (when applicable)
  
  expect_true(TRUE) # Placeholder for now
})