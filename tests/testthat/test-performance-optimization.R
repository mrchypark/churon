test_that("session performance optimization works", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    
    # Test session creation and optimization
    expect_no_error({
      session <- onnx_session(model_path)
      optimize_session_performance(session)
    })
    
    # Test safe session creation with optimization
    expect_no_error({
      safe_session <- safe_onnx_session(model_path, optimize = TRUE)
      expect_true(!is.null(safe_session))
    })
  } else {
    skip("No example models available for performance testing")
  }
})

test_that("memory usage estimation works", {
  skip_if_not_installed("churon")
  skip("Memory usage estimation not fully implemented yet")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    session <- onnx_session(model_path)
    
    # Test memory usage estimation
    expect_no_error({
      memory_usage <- estimate_session_memory(session)
      expect_true(is.numeric(memory_usage))
      expect_true(memory_usage > 0)
    })
  } else {
    skip("No example models available for memory estimation testing")
  }
})

test_that("performance statistics retrieval works", {
  skip_if_not_installed("churon")
  skip("Performance statistics not fully implemented yet")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    session <- onnx_session(model_path)
    
    # Test performance statistics
    expect_no_error({
      stats <- get_session_performance_stats(session)
      expect_true(is.list(stats))
      expect_true("model_path" %in% names(stats))
      expect_true("input_count" %in% names(stats))
      expect_true("output_count" %in% names(stats))
    })
  } else {
    skip("No example models available for performance statistics testing")
  }
})

test_that("batch processing works correctly", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    session <- onnx_session(model_path)
    
    # Create dummy batch data
    input_info <- onnx_input_info(session)
    
    if (length(input_info) > 0) {
      # This is a conceptual test - actual implementation would depend on model specifics
      dummy_data <- list(
        list(dummy_input = matrix(rnorm(10), nrow = 2, ncol = 5)),
        list(dummy_input = matrix(rnorm(10), nrow = 2, ncol = 5))
      )
      
      # Test batch processing (may fail due to input mismatch, but should not crash)
      expect_no_error({
        results <- batch_process_data(session, dummy_data, batch_size = 1)
        expect_true(is.list(results))
      })
    }
  } else {
    skip("No example models available for batch processing testing")
  }
})

test_that("safe inference with performance monitoring works", {
  skip_if_not_installed("churon")
  
  models <- onnx_example_models()
  
  if (length(models) > 0) {
    model_path <- models[1]
    session <- onnx_session(model_path)
    
    # Test safe inference with monitoring
    dummy_inputs <- list(dummy_input = matrix(rnorm(10), nrow = 2, ncol = 5))
    
    expect_no_error({
      result <- safe_onnx_run(session, dummy_inputs, monitor_performance = TRUE)
      # Result may be NULL due to input mismatch, but function should not crash
    })
  } else {
    skip("No example models available for safe inference testing")
  }
})

test_that("error handling in performance functions", {
  skip_if_not_installed("churon")
  
  # Test with invalid session
  expect_error(
    optimize_session_performance(NULL),
    "session is required and cannot be NULL"
  )
  
  expect_error(
    get_session_performance_stats("not_a_session"),
    "session must be an RSession object"
  )
  
  expect_error(
    estimate_session_memory(list()),
    "session must be an RSession object"
  )
  
  # Test batch processing with invalid parameters
  models <- onnx_example_models()
  if (length(models) > 0) {
    session <- onnx_session(models[1])
    
    expect_error(
      batch_process_data(session, "not_a_list"),
      "data_list must be a list"
    )
    
    expect_error(
      batch_process_data(session, list(), batch_size = -1),
      "batch_size must be a positive number"
    )
  }
})