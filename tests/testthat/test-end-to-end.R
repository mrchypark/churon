test_that("end-to-end workflow with example models", {
  skip_if_not_installed("churon")
  library(churon)
  
  # Get available example models
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    
    # Test complete workflow
    expect_no_error({
      # Create session
      session <- onnx_session(model_path)
      
      # Get model information
      input_info <- onnx_input_info(session)
      output_info <- onnx_output_info(session)
      providers <- onnx_providers(session)
      model_path_retrieved <- onnx_model_path(session)
      
      # Validate information
      expect_true(length(input_info) > 0)
      expect_true(length(output_info) > 0)
      expect_true(length(providers) > 0)
      expect_true(nchar(model_path_retrieved) > 0)
      expect_equal(normalizePath(model_path_retrieved), normalizePath(model_path))
    })
  } else {
    skip("No example models available for end-to-end testing")
  }
})

test_that("convenience functions work correctly", {
  skip_if_not_installed("churon")
  library(churon)
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_name <- names(models)[1]
    model_path <- models[1]

    # Test find_model_path with full path
    found_path <- find_model_path(model_path)
    expect_true(file.exists(found_path))
    expect_equal(normalizePath(found_path), normalizePath(model_path))

    # Test onnx_example_session
    expect_no_error({
      session <- onnx_example_session("mnist")
      expect_true(!is.null(session))
    })
  } else {
    skip("No example models available for convenience function testing")
  }
})

test_that("error handling in real scenarios", {
  skip_if_not_installed("churon")
  library(churon)
  
  # Test with non-existent model
  expect_error(
    onnx_session("/path/to/nonexistent/model.onnx"),
    "Model file not found"
  )
  
  # Test with invalid file
  temp_file <- tempfile(fileext = ".txt")
  writeLines("not an onnx model", temp_file)
  on.exit(unlink(temp_file))

  expect_error(
    suppressWarnings(onnx_session(temp_file)),
    "Failed to create ONNX session"
  )
  
  # Test with empty path
  expect_error(
    onnx_session(""),
    "model_path cannot be empty"
  )
  
  # Test with NULL path
  expect_error(
    onnx_session(NULL),
    "model_path is required and cannot be NULL"
  )
})

test_that("input validation works correctly", {
  skip_if_not_installed("churon")
  library(churon)
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    session <- onnx_session(models[1])
    
    # Test invalid session parameter
    expect_error(
      onnx_run(NULL, list(input = matrix(1:4, 2, 2))),
      "session is required and cannot be NULL"
    )
    
    expect_error(
      onnx_run("not_a_session", list(input = matrix(1:4, 2, 2))),
      "session must be an RSession object"
    )
    
    # Test invalid inputs parameter
    expect_error(
      onnx_run(session, NULL),
      "inputs is required and cannot be NULL"
    )
    
    expect_error(
      onnx_run(session, list()),
      "inputs cannot be empty"
    )
    
    expect_error(
      onnx_run(session, "not_a_list"),
      "inputs must be a named list"
    )
    
    # Test unnamed inputs
    expect_error(
      onnx_run(session, list(matrix(1:4, 2, 2))),
      "All inputs must be named"
    )
  } else {
    skip("No example models available for input validation testing")
  }
})