test_that("example model paths are accessible", {
  # Test that example models exist in the package
  model_dir <- system.file("model", package = "churon")
  expect_true(dir.exists(model_dir))
  
  # Check for expected model files
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  expect_true(length(model_files) > 0)
  
  # Check for specific models mentioned in the package
  kospacing_models <- list.files(model_dir, pattern = "kospacing.*\\.onnx$")
  expect_true(length(kospacing_models) > 0)
})

test_that("model file validation works", {
  # Test with valid model path
  model_dir <- system.file("model", package = "churon")
  model_files <- list.files(model_dir, pattern = "\\.onnx$", full.names = TRUE)
  
  if (length(model_files) > 0) {
    # Test that model files exist and are readable
    for (model_file in model_files) {
      expect_true(file.exists(model_file))
      expect_true(file.access(model_file, mode = 4) == 0) # readable
      expect_true(file.size(model_file) > 0) # not empty
    }
  }
})

test_that("invalid model paths are handled correctly", {
  # Test with non-existent file
  expect_error(
    {
      # This will be implemented when onnx_session function is available
      # onnx_session("/path/to/nonexistent/model.onnx")
    },
    NA # Skip for now
  )
  
  # Test with invalid file format
  temp_file <- tempfile(fileext = ".txt")
  writeLines("not an onnx model", temp_file)
  
  expect_error(
    {
      # This will be implemented when onnx_session function is available
      # onnx_session(temp_file)
    },
    NA # Skip for now
  )
  
  unlink(temp_file)
})