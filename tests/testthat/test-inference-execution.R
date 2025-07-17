test_that("basic inference execution", {
  skip_if_not_installed("churon")
  
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) > 0) {
    model_path <- model_files[1]
    
    # TODO: Implement when inference functions are available
    # session <- onnx_session(model_path)
    
    # Get input information to create appropriate test data
    # input_info <- onnx_input_info(session)
    
    # Create sample input data based on model requirements
    # This will need to be customized based on actual model inputs
    # sample_input <- list()
    # for (i in seq_along(input_info)) {
    #   input_spec <- input_info[[i]]
    #   # Create dummy data matching the expected shape and type
    #   if (input_spec$data_type == "Float32") {
    #     sample_data <- array(runif(prod(input_spec$shape)), dim = input_spec$shape)
    #   } else {
    #     sample_data <- array(as.integer(runif(prod(input_spec$shape)) * 100), 
    #                         dim = input_spec$shape)
    #   }
    #   sample_input[[input_spec$name]] <- sample_data
    # }
    
    # Run inference
    # result <- onnx_run(session, sample_input)
    # expect_type(result, "list")
    # expect_true(length(result) > 0)
    
    # For now, just test that model file exists
    expect_true(file.exists(model_path))
  } else {
    skip("No ONNX model files found for testing")
  }
})

test_that("inference with invalid input data", {
  skip_if_not_installed("churon")
  
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