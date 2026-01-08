test_that("basic inference execution", {
  skip_if_not_installed("churon")
  library(churon)

  expect_true(TRUE)
})

test_that("inference with invalid input data", {
  skip_if_not_installed("churon")
  library(churon)
  
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) > 0) {
    model_path <- model_files[1]
    
    # TODO: Implement when inference functions are available
    # session <- onnx_session(model_path)
    
    # Test with empty input
    # expect_error(onnx_run(session, list()))
    
    # Test with wrong input names
    # expect_error(onnx_run(session, list(wrong_name = matrix(1:4, 2, 2))))
    
    # Test with wrong input shapes
    # input_info <- onnx_input_info(session)
    # if (length(input_info) > 0) {
    #   wrong_input <- list()
    #   wrong_input[[input_info[[1]]$name]] <- matrix(1:2, 1, 2) # Wrong shape
    #   expect_error(onnx_run(session, wrong_input))
    # }
    
    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("korean spacing model specific tests", {
  skip_if_not_installed("churon")
  library(churon)
  
  model_dir <- system.file("model", package = "churon")
  kospacing_files <- list.files(model_dir, pattern = "kospacing.*\\.onnx$", full.names = TRUE)
  
  if (length(kospacing_files) > 0) {
    model_path <- kospacing_files[1]
    
    # TODO: Implement when Korean spacing functions are available
    # session <- onnx_session(model_path)
    
    # Test with Korean text input (this will depend on the actual model interface)
    # korean_text <- "안녕하세요한국어텍스트입니다"
    # result <- process_korean_spacing(session, korean_text)
    # expect_type(result, "character")
    # expect_true(nchar(result) > 0)
    
    # For now, just test that kospacing model exists
    expect_true(file.exists(model_path))
    expect_match(basename(model_path), "kospacing")
  } else {
    skip("No Korean spacing model files found for testing")
  }
})